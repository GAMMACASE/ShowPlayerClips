#include "sourcemod"
#include "sdktools"
#include "sdkhooks"
#include "dhooks"
#include "dhooks_macros"
#include "regex"

#define SNAME "[ShowPlayerClips] "
#define GAMECONF_FILENAME "showplayerclips.games"
#define TRANSLATE_FILENAME "showplayerclips.phrases"

#define MAX_TEMPENTS_SEND_CSS (255 - 24) //Rised to 255 with bytepatching.
#define MAX_TEMPENTS_SEND_CSGO (255 - 24)
#define PVIS_COUNT 3
#define TEMPENT_MIN_LIFETIME 1.0
#define TEMPENT_MAX_LIFETIME 25.0
#define INTERNAL_REFRESHTIME 0.1
//#define INTERNAL_DELTA 0.25

#define MAX_LEAF_PVERTS 128
#define NUMSIDES_BOXBRUSH 0xFFFF

public Plugin myinfo = 
{
	name = "Show Player Clip Brushes",
	author = "GAMMA CASE",
	description = "Shows player clip brushes on map.",
	version = "1.1.1",
	url = "https://github.com/GAMMACASE/ShowPlayerClips"
};

enum OSType
{
	OSUnknown = 0,
	OSWindows = 1,
	OSLinux = 2
};

OSType gOSType;
EngineVersion gEngineVer;

Handle ghLeafVisDraw,
	ghRecomputeClipbrushes,
//Linux only
	ghPolyFromPlane,
	ghClipPolyToPlane,
	ghMalloc,
	ghFree;
//==-

#include "spc/methodmaps.sp"
//#include "spc_debug"

ConVar gCvarCommands,
	gCvarBeamRefreshRate,
	gCvarBeamAlpha,
	gCvarBeamWidth,
	gCvarBeamSearchDelta,
	gCvarBeamMaterial;
//	gCvarDynamicTimer;

ArrayList gClientsToDraw;

VertsList gFinalVerts[PVIS_COUNT];

//TElimit bytepatch data
int gTELimitData[8];
int gTELimitDataSize;
Address gTELimitAddress;
//==-

//Linux only
CCollisionBSPData gpBSPData;
//==-

int gModelIndex,
	gpVisIdx,
	gDrawCount[PVIS_COUNT],
	gTotalCounter,
	gColor[PVIS_COUNT][4];

float gRefreshRate,
	gTickInterval;

bool gClipsPresent;
bool gCommandsRegistered = false;

Leafvis_t gpVis[PVIS_COUNT];

public void OnPluginStart()
{
	gCvarCommands = CreateConVar("spc_commands", "sm_showbrushes;sm_showclips;sm_showclipbrushes;sm_showplayerclips;sm_scb;sm_spc", "Available command names for toggling clip brushes visibility. (NOTE: Write command names with \"sm_\" prefix, and don't use ! or any other symbol except A-Z, 0-9 or underline symbol \"_\", also server needs to be restarted to see changes!)")
	gCvarBeamRefreshRate = CreateConVar("spc_beams_refresh_rate", "5.0", "Refresh rate at which beams will be drawn, don't set this to very low value! Map restart needed for this to take effect."/* (NOTE: Works only when \"spc_beams_refreshtime_dynamic\" set to 0)"*/, .hasMin = true, .min = 0.1, .hasMax = true, .max = TEMPENT_MAX_LIFETIME);
	gCvarBeamAlpha = CreateConVar("spc_beams_alpha", "255", "Alpha value for beams, lower = more transperent. Map restart needed for this to take effect.", .hasMin = true, .hasMax = true, .max = 255.0);
	gCvarBeamWidth = CreateConVar("spc_beams_width", "1.0", "Beams width, lower = less visible from distance.", .hasMin = true);
	gCvarBeamSearchDelta = CreateConVar("spc_beams_search_delta", "0.5", "Leave this value as default or a bit smaller then default. Lower the value, more precision for beams, more beams drawn, lower the fps will be. Set to 0 to disable. Map restart needed for this to take effect.", .hasMin = true);
	gCvarBeamMaterial = CreateConVar("spc_beams_material", "sprites/laserbeam.vmt", "Material used for beams. Server restart needed for this to take effect.");
	//TODO: Possibly a bad idea
	//gCvarDynamicTimer = CreateConVar("spc_beams_refreshtime_dynamic", "0", "Use dynamically calculated refresh time, may speed up showing beams when toggling command.", .hasMin = true, .hasMax = true, .max = 1.0);
	AutoExecConfig();
	
	LoadTranslations(TRANSLATE_FILENAME);
	
	gClientsToDraw = new ArrayList();
	
	gEngineVer = GetEngineVersion();
	gTickInterval = GetTickInterval();
	
	SETUP_GAMECONF(gconf, GAMECONF_FILENAME);
	
	GetOSType(gconf);
	RetrieveOffsets(gconf);
	SetupDhooks(gconf);
	SetupSDKCalls(gconf);
	
	if(gEngineVer == Engine_CSS)
		BytePatchTELimit(gconf);
	
	if(gOSType == OSLinux)
		GetCollisionBSPData(gconf);
	
	delete gconf;
}

public void OnPluginEnd()
{
	if(gTELimitAddress == Address_Null)
		return;
	
	for(int i = 0; i < gTELimitDataSize; i++)
		StoreToAddress(gTELimitAddress, gTELimitData[i], NumberType_Int8);
}

public void OnConfigsExecuted()
{
	char buff[PLATFORM_MAX_PATH];
	gCvarBeamMaterial.GetString(buff, sizeof(buff));
	gModelIndex = PrecacheModel(buff, true);

	if(!gCommandsRegistered)
		RegConsoleCommands();
}

public void RegConsoleCommands()
{
	char buff[1024];
	gCvarCommands.GetString(buff, sizeof(buff));
	
	if(buff[0] == '\0')
		return;
	
	char error[64];
	RegexError ErrorCode;
	Regex reg = new Regex("[a-zA-Z_0-9]+", 0, error, sizeof(error), ErrorCode);
	if(error[0] != '\0')
		SetFailState("[RegConsoleCommands] Regex error: \"%s\", with error code: %i", error, ErrorCode);
	
	int num = reg.MatchAll(buff, ErrorCode);
	if(ErrorCode != REGEX_ERROR_NONE)
		SetFailState("[RegConsoleCommands] Regex match error, error code: %i", ErrorCode);
	
	char sMatch[32];
	for(int i = 0; i < num; i++)
	{
		reg.GetSubString(0, sMatch, sizeof(sMatch), i);
		RegConsoleCmd(sMatch, SM_ShowClipBrushes, "Shows player clip brushes.");
	}
	gCommandsRegistered = true;
}

public void OnMapStart()
{
	if(gOSType == OSWindows)
	{
		SDKCall(ghRecomputeClipbrushes, true);
		SDKCall(ghLeafVisDraw);
	}
	else if(gOSType == OSLinux)
	{
		RecomputeClipbrushes();
	}
	
	CheckClipsPresent();
	
	/*if(gCvarDynamicTimer.BoolValue)
		gRefreshRate = float(GetTotalVertsCount()) / float(GetMaxTempEntsCount()) * INTERNAL_REFRESHTIME;
	else
		gRefreshRate = gCvarBeamRefreshRate.FloatValue;*/
	
	gRefreshRate = Clamp(gCvarBeamRefreshRate.FloatValue, TEMPENT_MIN_LIFETIME, TEMPENT_MAX_LIFETIME);
}

stock int GetTotalVertsCount()
{
	int count;
	for(int i = 0; i < PVIS_COUNT; i++)
		if(gFinalVerts[i])
			count += gFinalVerts[i].Length;
	
	return count;
}

stock void CheckClipsPresent()
{
	for(int i = 0; i < PVIS_COUNT; i++)
	{
		if(gFinalVerts[i])
		{
			gClipsPresent = true;
			return;
		}
	}
	
	gClipsPresent = false;
}

public void OnMapEnd()
{
	for(int i = 0; i < PVIS_COUNT; i++) 
	{
		if(gOSType == OSWindows)
			gpVis[i] = view_as<Leafvis_t>(0);
		
		delete gFinalVerts[i];
		for(int j = 0; j < sizeof(gColor); j++)
			gColor[i][j] = 0;
	}
	
	gpVisIdx = 0;
	gClipsPresent = false;
}

public void OnClientDisconnect(int client)
{
	int idx = gClientsToDraw.FindValue(GetClientUserId(client));
	if(idx != -1)
		gClientsToDraw.Erase(idx);
}

public void OnGameFrame()
{
	static int frameCounter;
	static float nextTime, timeDelta;
	static bool redrawing;
	
	if(!gClipsPresent)
		return;
	
	if(gClientsToDraw.Length == 0)
		return;
	
	if(!redrawing)
	{
		timeDelta = float(gTotalCounter) / float(GetMaxTempEntsCount()) * INTERNAL_REFRESHTIME;
		
		if(gRefreshRate - timeDelta > 0 && float(++frameCounter) / ((gRefreshRate - timeDelta) / gTickInterval) < 1.0)
			return;
		else
		{
			frameCounter = 0;
			
			for(int i = 0; i < PVIS_COUNT; i++)
				gDrawCount[i] = 0;
			gTotalCounter = 0;
		}
	}
	else if(nextTime > GetEngineTime())
		return;
	
	if(!DrawClipBrushes())
	{
		nextTime = GetEngineTime() + INTERNAL_REFRESHTIME;
		redrawing = true;
		return;
	}
	
	redrawing = false;
}

//TODO: Unused?
stock float PredictRefreshTime()
{
	static int clients[MAXPLAYERS], clients2[MAXPLAYERS];
	int counter, numclients;
	float vec[3];
	
	for(int i = 0; i < PVIS_COUNT; i++)
	{
		if(!gFinalVerts[i])
			continue;
		
		for(int j = 0; j < gFinalVerts[i].Length - 1; j++)
		{
			if(gFinalVerts[i].isLast(j) || (gFinalVerts[i].isOutside(j) || gFinalVerts[i].isOutside(j + 1)))
				continue;
			
			gFinalVerts[i].GetVerts(j, vec);
			
			numclients = GetClientsInRange(vec, RangeType_Visibility, clients, sizeof(clients));
			
			if(numclients == 0)
				continue;
			
			//FIXME:
			numclients = FilterClients(clients, numclients, clients2);
			
			if(numclients == 0)
				continue;
			
			counter++;
		}
	}
	
	return Clamp(float(counter) / float(GetMaxTempEntsCount()) * INTERNAL_REFRESHTIME, TEMPENT_MIN_LIFETIME, TEMPENT_MAX_LIFETIME);
}

public bool DrawClipBrushes()
{
	static int clients[MAXPLAYERS], clients2[MAXPLAYERS];
	int counter;
	float vec[3], vec2[3];
	int numclients;
	
	//GetClientsToDraw(clients, sizeof(clients));
	
	for(int i = 0; i < PVIS_COUNT; i++)
	{
		if(!gFinalVerts[i])
			continue;
		
		for(int j = gDrawCount[i]; j < gFinalVerts[i].Length - 1; j++)
		{
			if(gFinalVerts[i].isLast(j) || (gFinalVerts[i].isOutside(j) || gFinalVerts[i].isOutside(j + 1)))
				continue;
			
			gFinalVerts[i].GetVerts(j, vec);
			gFinalVerts[i].GetVerts(j + 1, vec2);
			
			//TODO: Rethink the way beams are drawn
			TE_SetupBeamPoints(vec, vec2, gModelIndex, 0, 0, 0, 
				//FIXME: Refresh time calculated absolutely wrong here
				Clamp(gRefreshRate + (gTotalCounter / GetMaxTempEntsCount() * INTERNAL_REFRESHTIME)/*gRefreshRate + INTERNAL_DELTA*/, TEMPENT_MIN_LIFETIME, TEMPENT_MAX_LIFETIME), 
				gCvarBeamWidth.FloatValue, gCvarBeamWidth.FloatValue, 0, 0.0, gColor[i], 0);
			
			numclients = GetClientsInRange(vec, RangeType_Visibility, clients, sizeof(clients));
			
			if(numclients == 0)
				continue;
			
			//FIXME:
			numclients = FilterClients(clients, numclients, clients2);
			
			if(numclients == 0)
				continue;
			
			TE_Send(clients2, numclients);
			
			counter++;
			gTotalCounter++;
			
			if(counter >= GetMaxTempEntsCount())
			{
				gDrawCount[i] = j;
				return false;
			}
		}
	}
	
	return true;
}

//FIXME:
stock int FilterClients(const int[] clients, int size, int[] outclients)
{
	int counter;
	for(int i = 0; i < size; i++)
	{
		if(gClientsToDraw.FindValue(GetClientUserId(clients[i])) != -1)
		{
			outclients[counter++] = clients[i];
		}
	}
	
	return counter;
}

stock int GetMaxTempEntsCount()
{
	return gEngineVer == Engine_CSGO ? MAX_TEMPENTS_SEND_CSGO : MAX_TEMPENTS_SEND_CSS
}

stock void GetClientsToDraw(int[] clients, int size)
{
	int client;
	for(int i = 0; i < gClientsToDraw.Length; i++)
	{
		if(i > size)
			break;
		
		client = GetClientOfUserId(gClientsToDraw.Get(i));
		
		if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client))
		{
			gClientsToDraw.Erase(i);
			i--;
			continue;
		}
		
		clients[i] = client;
	}
}

public Action SM_ShowClipBrushes(int client, int args)
{
	int idx = gClientsToDraw.FindValue(GetClientUserId(client));
	if(idx != -1)
	{
		gClientsToDraw.Erase(idx);
		ReplyToCommand(client, "%T", "playerclips_disabled", client);
	}
	else
	{
		gClientsToDraw.Push(GetClientUserId(client));
		ReplyToCommand(client, "%T", "playerclips_enabled", client);
	}
	
	return Plugin_Handled;
}

void GetOSType(Handle gconf)
{
	gOSType = view_as<OSType>(GameConfGetOffset(gconf, "WinOrLin"));
	
	ASSERT_MSG(gOSType != OSUnknown, "Failed to get OS type. Make sure gamedata file is in gamedata folder, and you are using windows or linux.");
}

void SetupDhooks(Handle gconf)
{
	if(gOSType == OSWindows)
	{
		//DrawLeafVis
		DHOOK_SETUP_DETOUR(dhook, CallConv_CDECL, ReturnType_Void, ThisPointer_Ignore, gconf, SDKConf_Signature, "DrawLeafVis");
		
		DHookAddParam(dhook, HookParamType_Int, .custom_register = (gEngineVer == Engine_CSGO ? DHookRegister_ECX : DHookRegister_Default));
		
		ASSERT_MSG(DHookEnableDetour(dhook, false, DrawLeafVis_CallBack), "Failed to enable detour for \"DrawLeafVis\".");
		
		if(gEngineVer == Engine_CSS)
		{
			//FindMinBrush
			DHOOK_SETUP_DETOUR(dhook2, CallConv_CDECL, ReturnType_Int, ThisPointer_Ignore, gconf, SDKConf_Signature, "FindMinBrush");
			
			DHookAddParam(dhook2, HookParamType_Int);
			DHookAddParam(dhook2, HookParamType_Int);
			DHookAddParam(dhook2, HookParamType_Int);
			
			ASSERT_MSG(DHookEnableDetour(dhook2, false, FindMinBrush_CallBack), "Failed to enable detour for \"FindMinBrush\".");
		}
	}
}

void SetupSDKCalls(Handle gconf)
{
	if(gOSType == OSWindows)
	{
		//LeafVisDraw
		StartPrepSDKCall(SDKCall_Static);
		ASSERT_MSG(PrepSDKCall_SetFromConf(gconf, SDKConf_Signature, "LeafVisDraw"), "Failed to get \"LeafVisDraw\" signature.");
		
		ghLeafVisDraw = EndPrepSDKCall();
		ASSERT_MSG(ghLeafVisDraw, "Failed to create SDKCall to \"LeafVisDraw\".");
		
		
		//RecomputeClipbrushes
		StartPrepSDKCall(SDKCall_Static);
		ASSERT_MSG(PrepSDKCall_SetFromConf(gconf, SDKConf_Signature, "RecomputeClipbrushes"), "Failed to get \"RecomputeClipbrushes\" signature.");
		
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		
		ghRecomputeClipbrushes = EndPrepSDKCall();
		ASSERT_MSG(ghRecomputeClipbrushes, "Failed to create SDKCall to \"RecomputeClipbrushes\".");
	}
	else if(gOSType == OSLinux)
	{	
		//PolyFromPlane
		StartPrepSDKCall(SDKCall_Static);
		ASSERT_MSG(PrepSDKCall_SetFromConf(gconf, SDKConf_Signature, "PolyFromPlane"), "Failed to get \"PolyFromPlane\" signature.");
		
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, .encflags = VENCODE_FLAG_COPYBACK);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		
		ghPolyFromPlane = EndPrepSDKCall();
		ASSERT_MSG(ghPolyFromPlane, "Failed to create SDKCall to \"PolyFromPlane\".");
		
		//ClipPolyToPlane
		StartPrepSDKCall(SDKCall_Static);
		ASSERT_MSG(PrepSDKCall_SetFromConf(gconf, SDKConf_Signature, "ClipPolyToPlane"), "Failed to get \"ClipPolyToPlane\" signature.");
		
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		
		ghClipPolyToPlane = EndPrepSDKCall();
		ASSERT_MSG(ghClipPolyToPlane, "Failed to create SDKCall to \"ClipPolyToPlane\".");
		
		//malloc
		StartPrepSDKCall(SDKCall_Static);
		ASSERT_MSG(PrepSDKCall_SetFromConf(gconf, SDKConf_Signature, "malloc"), "Failed to get \"malloc\" signature.");
		
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		if(gEngineVer == Engine_CSS)
			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		
		ghMalloc = EndPrepSDKCall();
		ASSERT_MSG(ghMalloc, "Failed to create SDKCall to \"malloc\".");
		
		//free
		StartPrepSDKCall(SDKCall_Static);
		ASSERT_MSG(PrepSDKCall_SetFromConf(gconf, SDKConf_Signature, "free"), "Failed to get \"free\" signature.");
		
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		if(gEngineVer == Engine_CSS)
			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		
		ghFree = EndPrepSDKCall();
		ASSERT_MSG(ghFree, "Failed to create SDKCall to \"free\".");
	}
}

void GetCollisionBSPData(Handle gconf)
{
	gpBSPData = CCollisionBSPData(GameConfGetAddress(gconf, "g_BSPData"));
	ASSERT_MSG(gpBSPData.Address != Address_Null, "Invalid gpBSPData retrieved from \"g_BSPData\" address.");
}

stock void BytePatchTELimit(Handle gconf)
{
	//TELimit
	gTELimitAddress = GameConfGetAddress(gconf, "TELimit");
	ASSERT_MSG(gTELimitAddress != Address_Null, "Failed to get addres of \"TELimit\".");
	
	gTELimitDataSize = GameConfGetOffset(gconf, "TELimitSize");
	ASSERT_MSG(gTELimitDataSize != 0, "0 length found in gamedata for \"TELimitSize\".");
	
	for(int i = 0; i < gTELimitDataSize; i++)
		gTELimitData[i] = LoadFromAddress(gTELimitAddress + i, NumberType_Int8);
	
	StoreToAddress(gTELimitAddress, 0x90909090, NumberType_Int32);
}

void RecomputeClipbrushes()
{
	int ibrush, contents[PVIS_COUNT] = {CONTENTS_PLAYERCLIP|CONTENTS_MONSTERCLIP, CONTENTS_MONSTERCLIP, CONTENTS_PLAYERCLIP};
	
	ArrayList planeList = new ArrayList(4);
	float normal[3], mins[3], maxs[3];
	Cbrush_t pBrush;
	Cboxbrush_t pBox;
	Cbrushside_t pSide;
	
	ArrayList vertsList = new ArrayList(3);
	ArrayList vertCountList = new ArrayList();
	
	int lastBrush = gpBSPData.numbrushes;
	if(gpBSPData.numcmodels > 1)
		lastBrush = FindMinBrush(view_as<Cmodel_t>(gpBSPData.map_cmodels.Get(1, Cmodel_t.Size())).headnode, lastBrush);
	
	for(int j = 0; j < PVIS_COUNT; j++)
	{
		vertsList.Clear();
		vertCountList.Clear();
		
		gColor[j][0] = (j != 1 ? 255 : 125);
		gColor[j][1] = 0;
		gColor[j][2] = (j != 0 ? 255 : 0);
		gColor[j][3] = gCvarBeamAlpha.IntValue;
		
		for(ibrush = 0; ibrush < lastBrush; ibrush++)
		{
			pBrush = view_as<Cbrush_t>(gpBSPData.map_brushes.Get(ibrush, Cbrush_t.Size()));
			if((pBrush.contents & (CONTENTS_PLAYERCLIP | CONTENTS_MONSTERCLIP)) == contents[j])
			{
				planeList.Clear();
				
				if(pBrush.IsBox())
				{
					pBox = view_as<Cboxbrush_t>(gpBSPData.map_boxbrushes.Get(pBrush.GetBox(), Cboxbrush_t.Size()));
					pBox.mins.ToArray(mins);
					pBox.maxs.ToArray(maxs);
					
					for(int i = 0; i < 3; i++)
					{
						normal[0] = 0.0;
						normal[1] = 0.0;
						normal[2] = 0.0;
						
						normal[i] = 1.0;
						
						AddPlaneToList(planeList, normal, maxs[i], true);
						NegateVector(normal);
						AddPlaneToList(planeList, normal, -mins[i], true);
					}
				}
				else
				{
					for(int i = 0; i < pBrush.numsides; i++)
					{
						pSide = view_as<Cbrushside_t>(gpBSPData.map_brushsides.Get(pBrush.firstbrushside + i, Cbrushside_t.Size()));
						
						if(pSide.bBevel == 1)
							continue;
						
						pSide.plane.normal.ToArray(normal);
						
						AddPlaneToList(planeList, normal, pSide.plane.dist, true);
					}
				}
				
				CSGPlaneList(planeList, vertsList, vertCountList);
			}
		}
		
		CalculateVertsLinux(j, vertsList, vertCountList);
	}
	
	delete vertsList;
	delete vertCountList;
	delete planeList;
}

int FindMinBrush(int nodenum, int brushIndex)
{
	int leafIndex, firstbrush;
	Cleaf_t leaf;
	Cnode_t node;
	
	for(;;)
	{
		if(nodenum < 0)
		{
			leafIndex = -1 - nodenum;
			
			if(leafIndex < 0 || leafIndex >= gpBSPData.map_leafs.m_nCount)
				return gpBSPData.numbrushes;
			
			leaf = view_as<Cleaf_t>(gpBSPData.map_leafs.Get(leafIndex, Cleaf_t.Size()));
			
			if(leaf.firstleafbrush >= gpBSPData.map_leafbrushes.m_nCount)
				return gpBSPData.numbrushes;
			
			firstbrush = gpBSPData.map_leafbrushes.GetValue(leaf.firstleafbrush, 2, NumberType_Int16);
			
			if(firstbrush < brushIndex)
				brushIndex = firstbrush;
			
			break;
		}
		
		node = view_as<Cnode_t>(gpBSPData.map_rootnode.Get(nodenum));
		brushIndex = FindMinBrush(node.children(0), brushIndex);
		nodenum = node.children(1);
	}
	
	return brushIndex;
}

void AddPlaneToList(ArrayList list, const float normal[3], float dist, bool invert)
{
	float plane_normal[3], plane_dist = invert ? -dist : dist;
	plane_normal[0] = invert ? -normal[0] : normal[0];
	plane_normal[1] = invert ? -normal[1] : normal[1];
	plane_normal[2] = invert ? -normal[2] : normal[2];
	
	float point[3], vec4d[4], d, vec[3];
	point = plane_normal;
	ScaleVector(point, plane_dist);
	for(int i = 0; i < list.Length; i++)
	{
		list.GetArray(i, vec4d);
		vec[0] = vec4d[0];
		vec[1] = vec4d[1];
		vec[2] = vec4d[2];
		if(vec[0] == plane_normal[0] && vec[1] == plane_normal[1] && vec[2] == plane_normal[2])
		{
			d = GetVectorDotProduct(point, vec) - vec4d[3];
			if(d > 0.0)
			{
				list.Set(i, plane_dist, 3);
			}
			
			return;
		}
	}
	
	vec4d[0] = plane_normal[0];
	vec4d[1] = plane_normal[1];
	vec4d[2] = plane_normal[2];
	vec4d[3] = plane_dist;
	list.PushArray(vec4d);
}

void CSGPlaneList(ArrayList planeList, ArrayList vertsList, ArrayList vertCountList)
{
	PseudoPtrArray vertsIn = PseudoPtrArray(MAX_LEAF_PVERTS, Vector.Size());
	PseudoPtrArray vertsOut = PseudoPtrArray(MAX_LEAF_PVERTS, Vector.Size());
	float insidePoint[3], normal[3], vec4d[4], verts[3];
	int vertCount, vertCount2;
	
	CSGInsidePoint(planeList, insidePoint);
	NegateVector(insidePoint);
	TranslatePlaneList(planeList, insidePoint);
	NegateVector(insidePoint);
	
	for(int i = 0; i < planeList.Length; i++)
	{
		planeList.GetArray(i, vec4d);
		normal[0] = vec4d[0];
		normal[1] = vec4d[1];
		normal[2] = vec4d[2];
		vertCount = SDKCall(ghPolyFromPlane, vertsIn.Address, normal, vec4d[3], 9000.0);
		
		for(int j = 0; j < planeList.Length; j++)
		{
			if(i == j)
				continue;
			
			if(vertCount < 3)
				continue;
			
			planeList.GetArray(j, vec4d);
			normal[0] = vec4d[0];
			normal[1] = vec4d[1];
			normal[2] = vec4d[2];
			
			vertCount = SDKCall(ghClipPolyToPlane, vertsIn.Address, vertCount, vertsOut.Address, normal, vec4d[3], 0.1);
			vertCount2 = 0;
			
			if(vertCount >= 4)
			{
				int tv = ((vertCount - 4) >> 2) + 1;
				vertCount2 = 4 * tv;
				
				int tv2;
				for(int k = 0; k < tv; k++)
				{
					view_as<Vector>(vertsOut.Get(tv2)).CopyTo(view_as<Vector>(vertsIn.Get(tv2)));
					view_as<Vector>(vertsOut.Get(tv2 + 1)).CopyTo(view_as<Vector>(vertsIn.Get(tv2 + 1)));
					view_as<Vector>(vertsOut.Get(tv2 + 2)).CopyTo(view_as<Vector>(vertsIn.Get(tv2 + 2)));
					view_as<Vector>(vertsOut.Get(tv2 + 3)).CopyTo(view_as<Vector>(vertsIn.Get(tv2 + 3)));
					
					tv2 += 4;
				}
			}
			
			if(vertCount2 < vertCount)
			{
				for(int k = 0; k < vertCount - vertCount2; k++)
					view_as<Vector>(vertsOut.Get(vertCount2 + k)).CopyTo(view_as<Vector>(vertsIn.Get(vertCount2 + k)));
			}
		}
		
		if(vertCount >= 3)
		{
			vertCountList.Push(vertCount);
			for(int j = 0; j < vertCount; j++)
			{
				view_as<Vector>(vertsIn.Get(j)).ToArray(verts);
				AddVectors(verts, insidePoint, verts);
				vertsList.PushArray(verts);
			}
		}
	}
	
	vertsIn.Free();
	vertsOut.Free();
}

void CSGInsidePoint(ArrayList planes, float point[3])
{
	float vec4d[4], normal[3], d;
	
	for(int i = 0; i < planes.Length; i++)
	{
		planes.GetArray(i, vec4d);
		
		normal[0] = vec4d[0];
		normal[1] = vec4d[1];
		normal[2] = vec4d[2];
		
		d = GetVectorDotProduct(normal, point) - vec4d[3];
		
		if(d < 0)
		{
			ScaleVector(normal, d);
			SubtractVectors(point, normal, point);
		}
	}
}

void TranslatePlaneList(ArrayList planes, float offset[3])
{
	float vec4d[4], normal[3];
	for(int i = 0; i < planes.Length; i++)
	{
		planes.GetArray(i, vec4d);
		
		normal[0] = vec4d[0];
		normal[1] = vec4d[1];
		normal[2] = vec4d[2];
		
		vec4d[3] += GetVectorDotProduct(offset, normal);
		
		planes.SetArray(i, vec4d);
	}
}

void CalculateVertsLinux(int pVisIdx, ArrayList vertsList, ArrayList vertCountList)
{
	gFinalVerts[pVisIdx] = new VertsList();
	ArrayList locvectors = new ArrayList(3);
	int vert, vertcount, lastidx;
	float vec[3], vec2[3];
	bool pointsOutside, pointsOutside2;
	
	for(int i = 0; i < vertCountList.Length; i++)
	{
		vertcount = vertCountList.Get(i);
		if(vertcount >= 3)
		{
			for(int j = 0; j < vertcount; j++)
			{
				vertsList.GetArray(vert + j, vec);
				vertsList.GetArray(vert + ((j + 1) % vertcount), vec2);
				
				pointsOutside = TR_PointOutsideWorld(vec);
				pointsOutside2 = TR_PointOutsideWorld(vec2);
				
				if(IsVectorInArray(locvectors, vec, vec2))
				{
					if(j == vertcount - 1 && lastidx != 0)
						gFinalVerts[pVisIdx].SetLast(lastidx, true);
					continue;
				}
				
				if(pointsOutside && !pointsOutside2)
					pointsOutside = RayTraceVerts(vec2, vec);
				else if(!pointsOutside && pointsOutside2)
					pointsOutside2 = RayTraceVerts(vec, vec2);
				
				gFinalVerts[pVisIdx].PushData(vec, false, pointsOutside);
				lastidx = gFinalVerts[pVisIdx].PushData(vec2, (j == vertcount - 1 ? true : false), pointsOutside2);
			}
		}
		
		lastidx = 0;
		vert += vertcount;
	}
	
	delete locvectors;
}

public MRESReturn DrawLeafVis_CallBack(Handle hParams)
{
	Leafvis_t pVis = Leafvis_t(DHookGetParam(hParams, 1));
	
	if(!pVis || (!pVis.verts.m_pElements || !pVis.polyVertCount.m_pElements) || (pVis.verts.Length == 0 || pVis.polyVertCount.Length == 0) || gpVisIdx > PVIS_COUNT - 1)
		return MRES_Supercede;
	
	gColor[gpVisIdx][0] = RoundToCeil(pVis.color.x * 255);
	gColor[gpVisIdx][1] = RoundToCeil(pVis.color.y * 255);
	gColor[gpVisIdx][2] = RoundToCeil(pVis.color.z * 255);
	gColor[gpVisIdx][3] = gCvarBeamAlpha.IntValue;
	
	gpVis[gpVisIdx] = pVis;
	
	CalculateVertsWindows();
	gpVisIdx++;
	
	return MRES_Supercede;
}

public MRESReturn FindMinBrush_CallBack(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, FindMinBrush2(DHookGetParam(hParams, 1), DHookGetParam(hParams, 2), DHookGetParam(hParams, 3)));
	
	return MRES_Supercede;
}

int FindMinBrush2(CCollisionBSPData bsp, int nodenum, int brushIndex)
{
	int leafIndex, firstbrush;
	Cleaf_t leaf;
	Cnode_t node;
	
	for(;;)
	{
		if(nodenum < 0)
		{
			leafIndex = -1 - nodenum;
			
			if(leafIndex < 0 || leafIndex >= bsp.map_leafs.m_nCount)
				return bsp.numbrushes;
			
			leaf = view_as<Cleaf_t>(bsp.map_leafs.Get(leafIndex, Cleaf_t.Size()));
			
			if(leaf.firstleafbrush >= bsp.map_leafbrushes.m_nCount)
				return bsp.numbrushes;
			
			firstbrush = bsp.map_leafbrushes.GetValue(leaf.firstleafbrush, 2, NumberType_Int16);
			
			if(firstbrush < brushIndex)
				brushIndex = firstbrush;
			
			break;
		}
		
		node = view_as<Cnode_t>(bsp.map_rootnode.Get(nodenum));
		brushIndex = FindMinBrush2(bsp, node.children(0), brushIndex);
		nodenum = node.children(1);
	}
	
	return brushIndex;
}

void CalculateVertsWindows()
{
	gFinalVerts[gpVisIdx] = new VertsList();
	ArrayList locvectors = new ArrayList(3);
	int vert, vertcount, lastidx;
	float vec[3], vec2[3];
	bool pointsOutside, pointsOutside2;
	
	for(int i = 0; i < gpVis[gpVisIdx].polyVertCount.Length; i++)
	{
		vertcount = gpVis[gpVisIdx].polyVertCount.Get(i);
		if(vertcount >= 3)
		{
			for(int j = 0; j < vertcount; j++)
			{
				gpVis[gpVisIdx].verts.Get(vert + j).ToArray(vec);
				gpVis[gpVisIdx].verts.Get(vert + ((j + 1) % vertcount)).ToArray(vec2);
				
				pointsOutside = TR_PointOutsideWorld(vec);
				pointsOutside2 = TR_PointOutsideWorld(vec2);
				
				if(IsVectorInArray(locvectors, vec, vec2))
				{
					if(j == vertcount - 1 && lastidx != 0)
						gFinalVerts[gpVisIdx].SetLast(lastidx, true);
					continue;
				}
				
				if(pointsOutside && !pointsOutside2)
					pointsOutside = RayTraceVerts(vec2, vec);
				else if(!pointsOutside && pointsOutside2)
					pointsOutside2 = RayTraceVerts(vec, vec2);
				
				gFinalVerts[gpVisIdx].PushData(vec, false, pointsOutside);
				lastidx = gFinalVerts[gpVisIdx].PushData(vec2, (j == vertcount - 1 ? true : false), pointsOutside2);
			}
		}
		
		lastidx = 0;
		vert += vertcount;
	}
	
	delete locvectors;
}

stock bool RayTraceVerts(const float a[3], float a2[3])
{
	TR_TraceRay(a, a2, MASK_SOLID, RayType_EndPoint);
	
	if(TR_DidHit())
	{
		TR_GetEndPosition(a2);
		return false;
	}
	
	return true;
}

//FIXME: This function is very unoptimized on maps with a lot of clip verts without hack!!!
stock bool IsVectorInArray(ArrayList vectors, float a1[3], float a2[3])
{
	float vec[3], orig[3], vec2[3], orig2[3];
	
	vec[0] = a1[0] - a2[0];
	vec[1] = a1[1] - a2[1];
	vec[2] = a1[2] - a2[2];
	orig = a2;
	
	vec2[0] = a2[0] - a1[0];
	vec2[1] = a2[1] - a1[1];
	vec2[2] = a2[2] - a1[2];
	orig2 = a1;
	
	float vecvec[3], vecorig[3];
	for(int i = /*HACK*/(vectors.Length > 32 ? vectors.Length - 32 : 0); i < vectors.Length; i += 2)
	{
		vectors.GetArray(i, vecvec);
		vectors.GetArray(i + 1, vecorig);
		if((ArrayEqual(orig, vecorig, gCvarBeamSearchDelta.FloatValue) && ArrayEqual(vec, vecvec, gCvarBeamSearchDelta.FloatValue)) ||
			(ArrayEqual(orig2, vecorig, gCvarBeamSearchDelta.FloatValue) && ArrayEqual(vec2, vecvec, gCvarBeamSearchDelta.FloatValue)))
			return true;
	}
	
	vectors.PushArray(vec);
	vectors.PushArray(orig);
	
	return false;
}

stock bool ArrayEqual(float l[3], float r[3], float delta = 0.0)
{
	return l[0] <= r[0] + delta && l[0] >= r[0] - delta && 
			l[1] <= r[1] + delta && l[1] >= r[1] - delta && 
			l[2] <= r[2] + delta && l[2] >= r[2] - delta;
}

stock float Clamp(float v, float min, float max)
{
	if (v < min) return min;
	if (v > max) return max;
	return v;
}

stock void Memset(Address dest, int src, int size)
{
	for(int i = 0; i < size; i++)
		StoreToAddress(dest + i, src, NumberType_Int8);
}

stock Address Malloc(int size)
{
	Address addr;
	
	if(gEngineVer == Engine_CSGO)
		addr = SDKCall(ghMalloc, size);
	else if(gEngineVer == Engine_CSS)
		addr = SDKCall(ghMalloc, 0, size);
	
	ASSERT_FMT(addr != Address_Null, "Failed to allocate memory. (%i)", size);
	
	return addr;
}

stock void Free(Address addr)
{
	ASSERT_MSG(addr != Address_Null, "Null address passed to free function.");
	
	if(gEngineVer == Engine_CSGO)
		SDKCall(ghFree, addr);
	else if(gEngineVer == Engine_CSS)
		SDKCall(ghFree, 0, addr);
}