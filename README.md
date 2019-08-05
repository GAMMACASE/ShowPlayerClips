# ShowPlayerClips
This plugin allows you to see clip brushes on maps, that normally you cannot see without sv_cheats enabled.

## Basic usage and examples:

To toggle clip brushes use one of the commands specified in ``spc_commands`` cvar. It will display 3 types of clip brushes, red = player clip; purple = monster clip; pink = both, player and monster clip, additionally on windows in csgo you may see green ones = grenade clips, they are not in linux version though.

Preview:
![example1](https://i.imgur.com/cHI0UzY.png)

## Available cvars:

* **spc_commands** - Commands that will be used to toggle clip brushes. Max is 20 commands and it's limited by 1024 characters;
* **spc_beams_refresh_rate** - Refresh rate at wich beams are redrawn, don't set this to very low value! Map restart needed for this to take effect;
* **spc_beams_alpha** - Alpha value for beams, lower = more transperent. Map restart needed for this to take effect;
* **spc_beams_width** - Beams width, lower = less visible from distance;
* **spc_beams_search_delta** - Leave this value as default or a bit smaller then default. Lower the value, more precision for beams, more beams drawn, lower the fps will be. Set to 0 to disable. Map restart needed for this to take effect;
* **spc_beams_material** - Material used for beams. Server restart needed for this to take effect.
