# CleanStrike Weapons Pack: adding a gun

Every pack gun is a vanilla gun's rig (arms, animations, handling, sounds,
effects) wearing a new model. Pick the vanilla gun whose *manual of arms*
matches: where the magazine goes in, which side the charging handle is on,
pistol vs rifle. That choice decides how natural every animation looks.

Dev project: `C:\RTVDev\RTVProject` (tools live in `cs_tools/weapons/`, copies
here). Run Godot tools windowed off-screen:
`Godot_v4.6.3-stable_win64_console.exe --windowed --resolution 320x180 --position -4000,100 --path . res://cs_tools/weapons/<Tool>.tscn`

1. **Source**: unzip into `cs_assets/<gun>/` (its own new folder; put
   `.gdignore` in texture folders). `.blend`: export to `.glb` with Blender
   headless (`blender -b x.blend --python blend2glb.py -- out.glb`); `.dae`
   imports directly (Blender 5 has no Collada). Import: `Godot --headless --import`.
2. **Inspect** (`Inspect.tscn`, `GUN=<gun>`): lists meshes and, in merged
   meshes, connected pieces with boxes; renders a numbered colour side view to
   `C:/RTVDev/inspect/<gun>.png`. Map pieces to roles from it.
3. **Spec** in `guns.gd`: `fwd`/`up` (source directions), real `length`,
   `base`, `skip` (display rounds, built-in scopes), `parts` (role -> meshes,
   or `{"mesh", "box"}` pieces of a merged mesh), `muzzle`, `ejector`, `rail`,
   `cells`. Roles: Body, Slide, Trigger, Hammer, Magazine, MagRelease, Charge,
   Selector, BoltRelease, SightRear, SightFront. Textures in `textures.json`
   (`dx: true` for DirectX normal maps), then `python -I prep_textures.py`.
4. **Build** (`Gunsmith.tscn`, `GUN=<ID>`): writes `CSWeapons/<ID>/Parts.scn`
   (one mesh per role in the base rig's skeleton space, trigger lined up with
   the base gun's, landmarks + icon framing as meta), `Icon.png`,
   `Icon_Inserted.png`, `Icon_Magazine.png`, and `C:/RTVDev/gunsmith/<ID>_fit.png`
   (hip view with the vanilla gun as a cyan ghost; aimed view through the new
   iron sights). Check both; nudge with `offset`.
5. **Game side**: copy the four files to `mods/WeaponsPack/CSWeaponsPack/Guns/<ID>/`
   and add the gun to `Guns.gd` (name, base, magazine, ammo, data, feel,
   optics). New calibres: `AMMO` in `Guns.gd`, box art from
   `ammo_boxes.py`, icons from `AmmoIcons.tscn`.

What the runtime (`Mod.gd`) does, and why:
- Vanilla weapon meshes get `mesh = null`, never hidden: the rig shows and
  hides its magazine/bullets during reloads and would bring them back.
- The new magazine becomes the rig's `magazine` export, so reloads, checks and
  empty guns show it the game's way.
- Muzzle/raycast/ejector move to the new gun; the top rounds move to the new
  magazine top; optics move to the new rail (the game aims at an optic's
  `position.y`), muzzle devices to the new muzzle.
- Iron sights: `data.aimPosition = -(front sight in the Attachments frame)`.
  Flip-up sights fold natively: new pivot bones, `backSightIndex` /
  `frontSightIndex`, `foldSights`, the game's angle -1.6 (rear pivot turned
  180 degrees so it folds forward).
- Handling.gd applies `position = (-x, y, -z)` of the data positions; the
  hip pose is `lowPosition`.
- Inventory picture: the base gun's tetris scene; children named after
  attachment files are shown when fitted, so the magazine child is renamed and
  given `Icon_Inserted.png` (same framing as the icon).
- Feel: recoil multiplies the base gun's numbers; sounds are the base gun's
  clips with `mix_rate` scaled (pitch) and volume added; muzzle flash scaled
  after each shot (0 = none).
- Never leave an instantiated node unfreed, even in tests: orphans crash the
  game on quit.
