static StringMap ghArraysMap;

#define DYNARRAY_START() if(!ghArraysMap) \
	ghArraysMap = new StringMap()

#define DYNARRAY_SETSIZE(%1,%2,%3) Format(%1, sizeof(%1), "%i_size", %2); \
	ghArraysMap.SetValue(%1, %3, true)
	
#define DYNARRAY_SETLENGTH(%1,%2,%3) Format(%1, sizeof(%1), "%i_length", %2); \
	ghArraysMap.SetValue(%1, %3, true)

#define DYNARRAY_SETTEMP(%1,%2,%3) Format(%1, sizeof(%1), "%i_temp", %2); \
	ghArraysMap.SetValue(%1, %3, true)

#define DYNARRAY_GETSIZE(%1,%2) Format(%1, sizeof(%1), "%i_size", this.Address); \
	ASSERT(!ghArraysMap.GetValue(%1, %2), "Failed to get length of the array from the ghArraysMap!")

#define DYNARRAY_GETLENGTH(%1,%2) Format(%1, sizeof(%1), "%i_length", this.Address); \
	ASSERT(!ghArraysMap.GetValue(%1, %2), "Failed to get size of each element from the ghArraysMap!")

#define DYNARRAY_GETTEMP(%1,%2) Format(%1, sizeof(%1), "%i_temp", this.Address); \
	ASSERT(!ghArraysMap.GetValue(%1, %2), "Failed to get temp from the ghArraysMap!")

#define DYNARRAY_END(%1) Format(%1, sizeof(%1), "%i_length", this.Address); \
	ghArraysMap.Remove(%1); \
	Format(%1, sizeof(%1), "%i_size", this.Address); \
	ghArraysMap.Remove(%1); \
	Format(%1, sizeof(%1), "%i_temp", this.Address); \
	ghArraysMap.Remove(%1); \
	if(ghArraysMap.Size == 0) \
		delete ghArraysMap

stock Address operator+(Address l, int r)
{
	return l + view_as<Address>(r);
}

methodmap AddressBase
{
	property Address Address
	{
		public get() { return view_as<Address>(this); }
	}
}

methodmap AllocatableBase < AddressBase
{
	public static Address _malloc(int size)
	{
		Address addr = Malloc(size);
		
		return addr;
	}
	
	public void _free()
	{
		Free(this.Address);
	}
}

enum CUtlVectorBase_members
{
	CUtlVectorBase_m_pMemory = 0,
	CUtlVectorBase_m_nAllocationCount = 1,
	CUtlVectorBase_m_nGrowSize,
	CUtlVectorBase_m_Size,
	CUtlVectorBase_m_pElements
};
static int CUtlVectorBase_offsets[CUtlVectorBase_members];

methodmap CUtlVectorBase < AllocatableBase
{
	property Address m_pMemory
	{
		public get() { return view_as<Address>(LoadFromAddress(this.Address + CUtlVectorBase_offsets[CUtlVectorBase_m_pMemory], NumberType_Int32)); }
	}
	
	property int m_nAllocationCount
	{
		public get() { return LoadFromAddress(this.Address + CUtlVectorBase_offsets[CUtlVectorBase_m_nAllocationCount], NumberType_Int32); }
	}
	
	property int m_nGrowSize
	{
		public get() { return LoadFromAddress(this.Address + CUtlVectorBase_offsets[CUtlVectorBase_m_nGrowSize], NumberType_Int32); }
	}
	
	property int m_Size
	{
		public get() { return LoadFromAddress(this.Address + CUtlVectorBase_offsets[CUtlVectorBase_m_Size], NumberType_Int32); }
	}
	
	property Address m_pElements
	{
		public get() { return view_as<Address>(LoadFromAddress(this.Address + CUtlVectorBase_offsets[CUtlVectorBase_m_pElements], NumberType_Int32)); }
	}
	
	property int Length
	{
		public get() { return this.m_Size; }
	}
}

methodmap Vector < AllocatableBase
{
	public static int Size()
	{
		return 12;
	}
	
	public Vector()
	{
		Address addr = AllocatableBase._malloc(Vector.Size());
		return view_as<Vector>(addr);
	}
	
	property float x
	{
		public set(float _x) { StoreToAddress(this.Address, view_as<int>(_x), NumberType_Int32); }
		public get() { return view_as<float>(LoadFromAddress(this.Address, NumberType_Int32)); }
	}
	
	property float y
	{
		public set(float _y) { StoreToAddress(this.Address + 4, view_as<int>(_y), NumberType_Int32); }
		public get() { return view_as<float>(LoadFromAddress(this.Address + 4, NumberType_Int32)); }
	}
	
	property float z
	{
		public set(float _z) { StoreToAddress(this.Address + 8, view_as<int>(_z), NumberType_Int32); }
		public get() { return view_as<float>(LoadFromAddress(this.Address + 8, NumberType_Int32)); }
	}
	
	public void ToArray(float buff[3])
	{
		buff[0] = this.x;
		buff[1] = this.y;
		buff[2] = this.z;
	}
	
	public void CopyTo(Vector dst)
	{
		dst.x = this.x;
		dst.y = this.y;
		dst.z = this.z;
	}
}

methodmap Vector4D < AddressBase
{
	public Vector4D(Address addr)
	{
		return view_as<Vector4D>(addr);
	}
	
	property float x
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address, NumberType_Int32)); }
	}
	
	property float y
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + 4, NumberType_Int32)); }
	}
	
	property float z
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + 8, NumberType_Int32)); }
	}
	
	property float w
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + 12, NumberType_Int32)); }
	}
	
	public void ToArray(float buff[4])
	{
		buff[0] = this.x;
		buff[1] = this.y;
		buff[2] = this.z;
		buff[3] = this.w;
	}
}

static int CUtlVectorUnknown_m_pElements_size;

methodmap CUtlVectorUnknown < CUtlVectorBase
{
	//No allocation
	public CUtlVectorUnknown(Address addr)
	{
		return view_as<CUtlVectorUnknown>(addr);
	}
	
	public int Get(int idx)
	{
		ASSERT(!this, "CUtlVectorUnknown trying to get values from null.");
		ASSERT_FMT(idx > this.Length, "CUtlVectorUnknown wrong idx passed. (%i, length %i)", idx, this.Length);
		
		return LoadFromAddress(this.m_pElements + (idx * CUtlVectorUnknown_m_pElements_size), NumberType_Int32);
	}
}

methodmap CUtlVectorVector < CUtlVectorBase
{
	//No allocation
	public CUtlVectorVector(Address addr)
	{
		return view_as<CUtlVectorVector>(addr);
	}
	
	public Vector Get(int idx)
	{
		ASSERT(!this, "CUtlVectorVector trying to get values from null.");
		ASSERT_FMT(idx > this.Length, "CUtlVectorVector wrong idx passed. (%i, length %i)", idx, this.Length);
		
		return view_as<Vector>(this.m_pElements + (idx * 12));
	}
}

methodmap CUtlVectorVector4D < CUtlVectorBase
{
	public CUtlVectorVector4D()
	{
		Address addr = AllocatableBase._malloc(20);
		
		return view_as<CUtlVectorVector4D>(addr);
	}
	
	public Vector4D Get(int idx)
	{
		ASSERT(!this, "CUtlVectorVector4D trying to get values from null.");
		ASSERT_FMT(idx > this.Length, "CUtlVectorVector4D wrong idx passed. (%i, length %i)", idx, this.Length);
		
		return view_as<Vector4D>(this.m_pElements + (idx * 16));
	}
}

enum Leafvis_t_members
{
	Leafvis_t_verts = 0,
	Leafvis_t_polyVertCount = 1,
	Leafvis_t_color,
	Leafvis_t_numbrushes,
	Leafvis_t_numentitychars,
	Leafvis_t_leafIndex
};
static int Leafvis_t_offsets[Leafvis_t_members];

methodmap Leafvis_t < AddressBase
{
	public Leafvis_t(Address addr)
	{
		return view_as<Leafvis_t>(addr);
	}
	
	property CUtlVectorVector verts
	{
		public get() { return view_as<CUtlVectorVector>(this.Address + Leafvis_t_offsets[Leafvis_t_verts]); }
	}
	
	property CUtlVectorUnknown polyVertCount
	{
		public get() { return view_as<CUtlVectorUnknown>(this.Address + Leafvis_t_offsets[Leafvis_t_polyVertCount]); }
	}
	
	property Vector color
	{
		public get() { return view_as<Vector>(this.Address + Leafvis_t_offsets[Leafvis_t_color]); }
	}
	
	property int numbrushes
	{
		public get() { return LoadFromAddress(this.Address + Leafvis_t_offsets[Leafvis_t_numbrushes], NumberType_Int32); }
	}
	
	property int numentitychars
	{
		public get() { return LoadFromAddress(this.Address + Leafvis_t_offsets[Leafvis_t_numentitychars], NumberType_Int32); }
	}
	
	property int leafIndex
	{
		public get() { return LoadFromAddress(this.Address + Leafvis_t_offsets[Leafvis_t_leafIndex], NumberType_Int32); }
	}
}

enum CRangeValidatedArray_members
{
	CRangeValidatedArray_m_pArray = 0,
	CRangeValidatedArray_m_nCount = 1
}
static int CRangeValidatedArray_offsets[CRangeValidatedArray_members];

methodmap CRangeValidatedArray < AddressBase
{
	public CRangeValidatedArray(Address addr)
	{
		return view_as<CRangeValidatedArray>(addr);
	}
	
	property Address m_pArray
	{
		public get() { return view_as<Address>(LoadFromAddress(this.Address + CRangeValidatedArray_offsets[CRangeValidatedArray_m_pArray], NumberType_Int32)); }
	}
	
	property int m_nCount
	{
		public get() 
		{
			ASSERT(gEngineVer == Engine_CSS, "Failed to get m_nCount member.");
			return LoadFromAddress(this.Address + CRangeValidatedArray_offsets[CRangeValidatedArray_m_nCount], NumberType_Int32);
		}
	}
	
	property int Length
	{
		public get() { return this.m_nCount; }
	}
	
	public Address Get(int idx, int sizeOfOneElem)
	{
		return this.m_pArray + (idx * sizeOfOneElem);
	}
	
	public any GetValue(int idx, int sizeOfOneElem, NumberType type)
	{
		return LoadFromAddress(this.m_pArray + (idx * sizeOfOneElem), type);
	}
}

enum Cbrush_t_members
{
	Cbrush_t_contents = 0,
	Cbrush_t_numsides = 1,
	Cbrush_t_firstbrushside
}
static int Cbrush_t_offsets[Cbrush_t_members];
static int Cbrush_t_size;

methodmap Cbrush_t < AddressBase
{
	public Cbrush_t(Address addr)
	{
		return view_as<Cbrush_t>(addr);
	}
	
	property int contents
	{
		public get() { return LoadFromAddress(this.Address + Cbrush_t_offsets[Cbrush_t_contents], NumberType_Int32); }
	}
	
	property int numsides
	{
		public get() { return LoadFromAddress(this.Address + Cbrush_t_offsets[Cbrush_t_numsides], NumberType_Int16); }
	}
	
	property int firstbrushside
	{
		public get() { return LoadFromAddress(this.Address + Cbrush_t_offsets[Cbrush_t_firstbrushside], NumberType_Int16); }
	}
	
	public int GetBox()
	{
		return this.firstbrushside;
	}
	
	public bool IsBox()
	{
		return this.numsides == NUMSIDES_BOXBRUSH;
	}
	
	public static int Size()
	{
		return Cbrush_t_size;
	}
}

enum Cboxbrush_t_members
{
	Cboxbrush_t_mins = 0,
	Cboxbrush_t_maxs = 1,
	Cboxbrush_t_surfaceIndex
}
static int Cboxbrush_t_offsets[Cboxbrush_t_members];
static int Cboxbrush_t_size;

methodmap Cboxbrush_t < AddressBase
{
	public Cboxbrush_t(Address addr)
	{
		return view_as<Cboxbrush_t>(addr);
	}
	
	property Vector mins
	{
		public get() { return view_as<Vector>(this.Address + Cboxbrush_t_offsets[Cboxbrush_t_mins]); }
	}
	
	property Vector maxs
	{
		public get() { return view_as<Vector>(this.Address + Cboxbrush_t_offsets[Cboxbrush_t_maxs]); }
	}
	
	public void surfaceIndex(int out[6])
	{
		for(int i = 0; i < 6; i++)
			out[i] = LoadFromAddress(this.Address + Cboxbrush_t_offsets[Cboxbrush_t_surfaceIndex] + (2 * i), NumberType_Int16);
	}
	
	public static int Size()
	{
		return Cboxbrush_t_size;
	}
}

enum Cplane_t_members
{
	Cplane_t_normal = 0,
	Cplane_t_dist = 1,
	Cplane_t_type,
	Cplane_t_signbits
};
static int Cplane_t_offsets[Cplane_t_members];

methodmap Cplane_t < AddressBase
{
	public Cplane_t(Address addr)
	{
		return view_as<Cplane_t>(addr);
	}
	
	property Vector normal
	{
		public get() { return view_as<Vector>(this.Address + Cplane_t_offsets[Cplane_t_normal]); }
	}
	
	property float dist
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + Cplane_t_offsets[Cplane_t_dist], NumberType_Int32)); }
	}
	
	property int type
	{
		public get() { return LoadFromAddress(this.Address + Cplane_t_offsets[Cplane_t_type], NumberType_Int8); }
	}
	
	property int signbits
	{
		public get() { return LoadFromAddress(this.Address + Cplane_t_offsets[Cplane_t_signbits], NumberType_Int8); }
	}
}

enum Cnode_t_members
{
	Cnode_t_plane = 0,
	Cnode_t_children = 1
}
static int Cnode_t_offsets[Cboxbrush_t_members];
static int Cnode_t_size;

methodmap Cnode_t < AddressBase
{
	public Cnode_t(Address addr)
	{
		return view_as<Cnode_t>(addr);
	}
	
	property Cplane_t plane
	{
		public get() { return view_as<Cplane_t>(LoadFromAddress(this.Address + Cnode_t_offsets[Cnode_t_plane], NumberType_Int32)); }
	}
	
	public int children(int idx)
	{
		ASSERT(idx > 2, "Failed to get children member from cnode_t.");
		
		return LoadFromAddress(this.Address + Cnode_t_offsets[Cnode_t_children] + (4 * idx), NumberType_Int32);
	}
	
	public static int Size()
	{
		return Cnode_t_size;
	}
}

enum Cmodel_t_members
{
	Cmodel_t_mins = 0,
	Cmodel_t_maxs = 1,
	Cmodel_t_origin,
	Cmodel_t_headnode
	//...
}
static int Cmodel_t_offsets[Cmodel_t_members];
static int Cmodel_t_size;

methodmap Cmodel_t < AddressBase
{
	public Cmodel_t(Address addr)
	{
		return view_as<Cmodel_t>(addr);
	}
	
	property Vector mins
	{
		public get() { return view_as<Vector>(this.Address + Cmodel_t_offsets[Cmodel_t_mins]); }
	}
	
	property Vector maxs
	{
		public get() { return view_as<Vector>(this.Address + Cmodel_t_offsets[Cmodel_t_maxs]); }
	}
	
	property Vector origin
	{
		public get() { return view_as<Vector>(this.Address + Cmodel_t_offsets[Cmodel_t_origin]); }
	}
	
	property int headnode
	{
		public get() { return LoadFromAddress(this.Address + Cmodel_t_offsets[Cmodel_t_headnode], NumberType_Int32); }
	}
	
	//...
	
	public static int Size()
	{
		return Cmodel_t_size;
	}
}

enum BrushSideInfo_t_members
{
	BrushSideInfo_t_plane = 0,
	BrushSideInfo_t_bevel = 1,
	BrushSideInfo_t_thin
};
static int BrushSideInfo_t_offsets[BrushSideInfo_t_members];
static int BrushSideInfo_t_size;

methodmap BrushSideInfo_t < AddressBase
{
	public BrushSideInfo_t(Address addr)
	{
		return view_as<BrushSideInfo_t>(addr);
	}
	
	property Vector4D plane_Vector4D
	{
		public get()
		{
			ASSERT(gEngineVer != Engine_CSS, "Trying to get wrong member for BrushSideInfo_t (plane)");
			return view_as<Vector4D>(this.Address + BrushSideInfo_t_offsets[BrushSideInfo_t_plane]);
		}
	}
	
	property Cplane_t plane_cplane_t
	{
		public get() 
		{ 
			ASSERT(gEngineVer != Engine_CSGO, "Trying to get wrong member for BrushSideInfo_t (plane)");
			return view_as<Cplane_t>(this.Address + BrushSideInfo_t_offsets[BrushSideInfo_t_plane]);
		}
	}
	
	property int bevel
	{
		public get() { return LoadFromAddress(this.Address + BrushSideInfo_t_offsets[BrushSideInfo_t_bevel], NumberType_Int16); }
	}
	
	property int thin
	{
		public get() { return LoadFromAddress(this.Address + BrushSideInfo_t_offsets[BrushSideInfo_t_thin], NumberType_Int16); }
	}
	
	public static int Size()
	{
		return BrushSideInfo_t_size;
	}
}

enum Cleaf_t_members
{
	Cleaf_t_contents = 0,
	Cleaf_t_cluster = 1,
	Cleaf_t_area,
	Cleaf_t_flags,
	Cleaf_t_firstleafbrush,
	Cleaf_t_numleafbrushes,
	Cleaf_t_dispListStart,
	Cleaf_t_dispCount
};
static int Cleaf_t_offsets[Cleaf_t_members];
static int Cleaf_t_size;

methodmap Cleaf_t < AddressBase
{
	public Cleaf_t(Address addr)
	{
		return view_as<Cleaf_t>(addr);
	}
	
	property int contents
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_contents], NumberType_Int32); }
	}
	
	property int cluster
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_cluster], NumberType_Int16); }
	}
	
	property int area
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_area], NumberType_Int8); }
	}
	
	property int flags
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_flags], NumberType_Int8); }
	}
	
	property int firstleafbrush
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_firstleafbrush], NumberType_Int16); }
	}
	
	property int numleafbrushes
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_numleafbrushes], NumberType_Int16); }
	}
	
	property int dispListStart
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_dispListStart], NumberType_Int16); }
	}
	
	property int dispCount
	{
		public get() { return LoadFromAddress(this.Address + Cleaf_t_offsets[Cleaf_t_dispCount], NumberType_Int16); }
	}
	
	public static int Size()
	{
		return Cleaf_t_size;
	}
}

enum Cbrushside_t_members
{
	Cbrushside_t_plane = 0,
	Cbrushside_t_surfaceIndex = 1,
	Cbrushside_t_bBevel
};
static int Cbrushside_t_offsets[Cbrushside_t_members];
static int Cbrushside_t_size;

methodmap Cbrushside_t < AddressBase
{
	public Cbrushside_t(Address addr)
	{
		return view_as<Cbrushside_t>(addr);
	}
	
	property Cplane_t plane
	{
		public get() { return view_as<Cplane_t>(LoadFromAddress(this.Address + Cbrushside_t_offsets[Cbrushside_t_plane], NumberType_Int32)); }
	}
	
	property int surfaceIndex
	{
		public get() { return LoadFromAddress(this.Address + Cbrushside_t_offsets[Cbrushside_t_surfaceIndex], NumberType_Int16); }
	}
	
	property int bBevel
	{
		public get() { return LoadFromAddress(this.Address + Cbrushside_t_offsets[Cbrushside_t_bBevel], NumberType_Int16); }
	}
	
	public static int Size()
	{
		return Cbrushside_t_size;
	}
}

methodmap PseudoPtrArray < AllocatableBase
{
	public PseudoPtrArray(int length, int sizeOfOneElem)
	{
		Address addr = AllocatableBase._malloc(length * sizeOfOneElem);
		DYNARRAY_START();
		
		char buff[32];
		
		DYNARRAY_SETSIZE(buff, addr, sizeOfOneElem);
		DYNARRAY_SETLENGTH(buff, addr, length);
		DYNARRAY_SETTEMP(buff, addr, false);
		
		Memset(addr, 0, length * sizeOfOneElem);
		
		return view_as<PseudoPtrArray>(addr);
	}
	
	public static PseudoPtrArray FromAddress(Address addr, int length, int sizeOfOneElem, bool temp = false)
	{
		ASSERT(addr == Address_Null, "Null address passed to PseudoPtrArray constructor!");
		DYNARRAY_START();
		
		char buff[32];
		
		DYNARRAY_SETSIZE(buff, addr, sizeOfOneElem);
		DYNARRAY_SETLENGTH(buff, addr, length);
		DYNARRAY_SETTEMP(buff, addr, temp);
		
		return view_as<PseudoPtrArray>(addr);
	}
	
	public void Free(bool full = true)
	{
		if(full)
			this._free();
		
		char buff[32];
		DYNARRAY_END(buff);
	}
	
	public Address Get(int idx)
	{
		int ibuff;
		char buff[32];
		DYNARRAY_GETLENGTH(buff, ibuff);
		if(ibuff != -1)
			ASSERT_FMT(idx >= ibuff || idx < 0, "Invalid idx for PseudoPtrArray (%i, length %i)", idx, ibuff);
		
		DYNARRAY_GETSIZE(buff, ibuff);
		
		bool temp;
		DYNARRAY_GETTEMP(buff, temp);
		
		if(!temp)
			return this.Address + (idx * ibuff);
		else
		{
			this.Free(false);
			return this.Address + (idx * ibuff);
		}
	}
	
	property int Length
	{
		public get()
		{
			int len;
			char buff[32];
			DYNARRAY_GETLENGTH(buff, len);
			
			return len;
		}
	}
}

enum CCollisionBSPData_members
{
	CCollisionBSPData_map_rootnode = 0,
	CCollisionBSPData_map_name = 1,
	CCollisionBSPData_numbrushsides,
	CCollisionBSPData_map_brushsides,
	CCollisionBSPData_numboxbrushes,
	CCollisionBSPData_map_boxbrushes,
	CCollisionBSPData_numplanes,
	CCollisionBSPData_map_planes,
	CCollisionBSPData_numnodes,
	CCollisionBSPData_map_nodes,
	CCollisionBSPData_numleafs,
	CCollisionBSPData_map_leafs,
	CCollisionBSPData_emptyleaf,
	CCollisionBSPData_solidleaf,
	CCollisionBSPData_numleafbrushes,
	CCollisionBSPData_map_leafbrushes,
	CCollisionBSPData_numcmodels,
	CCollisionBSPData_map_cmodels,
	CCollisionBSPData_numbrushes,
	CCollisionBSPData_map_brushes,
	CCollisionBSPData_numdisplist,
	CCollisionBSPData_map_dispList
	//...
};
static int CCollisionBSPData_offsets[CCollisionBSPData_members];

methodmap CCollisionBSPData < AddressBase
{
	public CCollisionBSPData(Address addr)
	{
		return view_as<CCollisionBSPData>(addr);
	}
	
	property PseudoPtrArray map_rootnode
	{
		public get() { return PseudoPtrArray.FromAddress(view_as<Address>(LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_rootnode], NumberType_Int32)), -1, Cnode_t.Size(), true); }
	}
	
	//...
	
	property int numbrushsides
	{
		public get() { return LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_numbrushsides], NumberType_Int32); }
	}
	
	property CRangeValidatedArray map_brushsides
	{
		public get() { return view_as<CRangeValidatedArray>(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_brushsides]); }
	}
	
	property int numboxbrushes
	{
		public get() { return LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_numboxbrushes], NumberType_Int32); }
	}
	
	property CRangeValidatedArray map_boxbrushes
	{
		public get() { return view_as<CRangeValidatedArray>(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_boxbrushes]); }
	}
	
	//...
	
	property int numleafs
	{
		public get() { return LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_numleafs], NumberType_Int32); }
	}
	
	property CRangeValidatedArray map_leafs
	{
		public get() { return view_as<CRangeValidatedArray>(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_leafs]); }
	}
	
	//...
	
	property int numleafbrushes
	{
		public get() { return LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_numleafbrushes], NumberType_Int32); }
	}
	
	property CRangeValidatedArray map_leafbrushes
	{
		public get() { return view_as<CRangeValidatedArray>(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_leafbrushes]); }
	}
	
	property int numcmodels
	{
		public get() { return LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_numcmodels], NumberType_Int32); }
	}
	
	property CRangeValidatedArray map_cmodels
	{
		public get() { return view_as<CRangeValidatedArray>(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_cmodels]); }
	}
	
	property int numbrushes
	{
		public get() { return LoadFromAddress(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_numbrushes], NumberType_Int32); }
	}
	
	property CRangeValidatedArray map_brushes
	{
		public get() { return view_as<CRangeValidatedArray>(this.Address + CCollisionBSPData_offsets[CCollisionBSPData_map_brushes]); }
	}
	
	//...
}

void RetrieveOffsets(Handle gconf)
{
	char buff[32];
	
	if(gOSType == OSWindows)
	{
		//Leafvis_t
		GameConfGetKeyValue(gconf, "leafvis_t::verts", buff, sizeof(buff));
		Leafvis_t_offsets[Leafvis_t_verts] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "leafvis_t::polyVertCount", buff, sizeof(buff));
		Leafvis_t_offsets[Leafvis_t_polyVertCount] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "leafvis_t::color", buff, sizeof(buff));
		Leafvis_t_offsets[Leafvis_t_color] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "leafvis_t::numbrushes", buff, sizeof(buff));
		Leafvis_t_offsets[Leafvis_t_numbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "leafvis_t::numentitychars", buff, sizeof(buff));
		Leafvis_t_offsets[Leafvis_t_numentitychars] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "leafvis_t::leafIndex", buff, sizeof(buff));
		Leafvis_t_offsets[Leafvis_t_leafIndex] = StringToInt(buff);
		
		//CUtlVector
		GameConfGetKeyValue(gconf, "CUtlVector::m_pMemory", buff, sizeof(buff));
		CUtlVectorBase_offsets[CUtlVectorBase_m_pMemory] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CUtlVector::m_nAllocationCount", buff, sizeof(buff));
		CUtlVectorBase_offsets[CUtlVectorBase_m_nAllocationCount] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CUtlVector::m_nGrowSize", buff, sizeof(buff));
		CUtlVectorBase_offsets[CUtlVectorBase_m_nGrowSize] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CUtlVector::m_Size", buff, sizeof(buff));
		CUtlVectorBase_offsets[CUtlVectorBase_m_Size] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CUtlVector::m_pElements", buff, sizeof(buff));
		CUtlVectorBase_offsets[CUtlVectorBase_m_pElements] = StringToInt(buff);
		
		//CUtlVectorUnknown::m_pElements::size
		GameConfGetKeyValue(gconf, "CUtlVectorUnknown::m_pElements::size", buff, sizeof(buff));
		CUtlVectorUnknown_m_pElements_size = StringToInt(buff);
	}
	else if(gOSType == OSLinux)
	{
		//CRangeValidatedArray
		GameConfGetKeyValue(gconf, "CRangeValidatedArray::m_pArray", buff, sizeof(buff));
		CRangeValidatedArray_offsets[CRangeValidatedArray_m_pArray] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CRangeValidatedArray::m_nCount", buff, sizeof(buff));
		CRangeValidatedArray_offsets[CRangeValidatedArray_m_nCount] = StringToInt(buff);
		
		//cnode_t
		GameConfGetKeyValue(gconf, "cnode_t::plane", buff, sizeof(buff));
		Cnode_t_offsets[Cnode_t_plane] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cnode_t::children", buff, sizeof(buff));
		Cnode_t_offsets[Cnode_t_children] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cnode_t::size", buff, sizeof(buff));
		Cnode_t_size = StringToInt(buff);
		
		//cboxbrush_t
		GameConfGetKeyValue(gconf, "cboxbrush_t::mins", buff, sizeof(buff));
		Cboxbrush_t_offsets[Cboxbrush_t_mins] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cboxbrush_t::maxs", buff, sizeof(buff));
		Cboxbrush_t_offsets[Cboxbrush_t_maxs] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cboxbrush_t::surfaceIndex", buff, sizeof(buff));
		Cboxbrush_t_offsets[Cboxbrush_t_surfaceIndex] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cboxbrush_t::size", buff, sizeof(buff));
		Cboxbrush_t_size = StringToInt(buff);
		
		//cbrush_t
		GameConfGetKeyValue(gconf, "cbrush_t::contents", buff, sizeof(buff));
		Cbrush_t_offsets[Cbrush_t_contents] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cbrush_t::numsides", buff, sizeof(buff));
		Cbrush_t_offsets[Cbrush_t_numsides] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cbrush_t::firstbrushside", buff, sizeof(buff));
		Cbrush_t_offsets[Cbrush_t_firstbrushside] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cbrush_t::size", buff, sizeof(buff));
		Cbrush_t_size = StringToInt(buff);
		
		//cleaf_t
		GameConfGetKeyValue(gconf, "cleaf_t::contents", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_contents] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::cluster", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_cluster] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::area", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_area] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::flags", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_flags] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::firstleafbrush", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_firstleafbrush] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::numleafbrushes", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_numleafbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::dispListStart", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_dispListStart] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::dispCount", buff, sizeof(buff));
		Cleaf_t_offsets[Cleaf_t_dispCount] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cleaf_t::size", buff, sizeof(buff));
		Cleaf_t_size = StringToInt(buff);
		
		//cbrushside_t
		GameConfGetKeyValue(gconf, "cbrushside_t::plane", buff, sizeof(buff));
		Cbrushside_t_offsets[Cbrushside_t_plane] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cbrushside_t::surfaceIndex", buff, sizeof(buff));
		Cbrushside_t_offsets[Cbrushside_t_surfaceIndex] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cbrushside_t::bBevel", buff, sizeof(buff));
		Cbrushside_t_offsets[Cbrushside_t_bBevel] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cbrushside_t::size", buff, sizeof(buff));
		Cbrushside_t_size = StringToInt(buff);
		
		//cmodel_t
		GameConfGetKeyValue(gconf, "cmodel_t::mins", buff, sizeof(buff));
		Cmodel_t_offsets[Cmodel_t_mins] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cmodel_t::maxs", buff, sizeof(buff));
		Cmodel_t_offsets[Cmodel_t_maxs] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cmodel_t::origin", buff, sizeof(buff));
		Cmodel_t_offsets[Cmodel_t_origin] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cmodel_t::headnode", buff, sizeof(buff));
		Cmodel_t_offsets[Cmodel_t_headnode] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cmodel_t::size", buff, sizeof(buff));
		Cmodel_t_size = StringToInt(buff);
		
		//CCollisionBSPData
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_rootnode", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_rootnode] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::numbrushsides", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_numbrushsides] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_brushsides", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_brushsides] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::numboxbrushes", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_numboxbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_boxbrushes", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_boxbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::numleafs", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_numleafs] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_leafs", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_leafs] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::numleafbrushes", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_numleafbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_leafbrushes", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_leafbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::numcmodels", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_numcmodels] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_cmodels", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_cmodels] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::numbrushes", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_numbrushes] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "CCollisionBSPData::map_brushes", buff, sizeof(buff));
		CCollisionBSPData_offsets[CCollisionBSPData_map_brushes] = StringToInt(buff);
		
		//cplane_t
		GameConfGetKeyValue(gconf, "cplane_t::normal", buff, sizeof(buff));
		Cplane_t_offsets[Cplane_t_normal] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cplane_t::dist", buff, sizeof(buff));
		Cplane_t_offsets[Cplane_t_dist] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cplane_t::type", buff, sizeof(buff));
		Cplane_t_offsets[Cplane_t_type] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "cplane_t::signbits", buff, sizeof(buff));
		Cplane_t_offsets[Cplane_t_signbits] = StringToInt(buff);
		
		//BrushSideInfo_t
		GameConfGetKeyValue(gconf, "BrushSideInfo_t::plane", buff, sizeof(buff));
		BrushSideInfo_t_offsets[BrushSideInfo_t_plane] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "BrushSideInfo_t::bevel", buff, sizeof(buff));
		BrushSideInfo_t_offsets[BrushSideInfo_t_bevel] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "BrushSideInfo_t::thin", buff, sizeof(buff));
		BrushSideInfo_t_offsets[BrushSideInfo_t_thin] = StringToInt(buff);
		GameConfGetKeyValue(gconf, "BrushSideInfo_t::Size", buff, sizeof(buff));
		BrushSideInfo_t_size = StringToInt(buff);
	}
}