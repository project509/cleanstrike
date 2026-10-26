# CleanStrike Weapons Pack pipeline (work in progress)

FN SCAR-17 from `ideaboard/FN SCAR.zip` (model by Gybels Tristan; used for this
free fan mod with the owner's permission). Extract `source/Low.rar` (Windows
`tar -xf` reads RAR), copy `straigth model/*.FBX` to
`RTVProject/cs_assets/scar/SCAR_straight.fbx` and the textures to
`cs_assets/scar/textures/`, import with `fbx/importer=0`, then run
`Build.tscn` (windowed, off-screen). Output: `CSWeapons/Model/SCAR_Parts.scn`,
every part textured and placed in the KAR-21 (.308) rig's space (scale
0.0297, barrel along +Z, magazine well and muzzle on the KAR-21's), plus a
side-view check in `C:\RTVDev\scar_preview.png`.

Next: mount the parts on the KAR-21 rig's bones in game (charging handle,
trigger, selector, magazine, release levers move with their bones), raise
optic mounts to the SCAR rail, move muzzle devices to its muzzle; item data,
icons, world model, Database, loot and traders; self-test.
