# CleanStrike Zombies asset pipeline (work in progress)

Builds the zombie character used by the CleanStrike Zombies mod from the
assets in `ideaboard/zombies/` (zombie model + Mixamo animation packs).
Runs in the recovered dev project (`C:\RTVDev\RTVProject`) with the Godot
4.6.3 editor, hidden/off-screen.

1. Stage the assets under `RTVProject/cs_assets/zombies/` (`model/`,
   `textures/` from `zombie.zip`, `mixamo_a/`, `mixamo_b/` via
   `stage_assets.py`).
2. `maps.gd` (run with `-s`): humanoid bone maps for the Mixamo rig and the
   zombie's 3ds Max Biped rig -> `cs_assets/zombies/maps/`.
3. `import_settings.py`: points every FBX import at its bone map (retarget to
   the humanoid profile; keep `fbx/importer=0`, the built-in ufbx), then
   `Godot --headless --import`.
4. `Build.tscn` / `build_zombie.gd` (windowed, off-screen): one
   self-contained `CSZombies/Model/Zombie.scn` (meshes, skins, S3TC textures
   embedded; 31 clips in its AnimationPlayer, root motion removed) and preview
   renders in `C:\RTVDev\zombie_preview\`.

Status (2026-10-26): pipeline works; all clips retarget and play on the
zombie; textured export verified by reloading it. The model is split into
per-limb meshes (Z_Head, Z_L_Forearm, ...), which dismemberment will use.
The model imports at root scale 0.01 (it is in centimetres).
mods/Zombies (0.1.0, opt-in, In Progress) ships Zombie.scn; its self-test
checks it loads in the game, limbs, 31 clips, human size, crawl height.
Next: zombie AI replacing the game's enemies.
