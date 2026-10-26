# Cleanstrike

A mod manager and loader for **Road to Vostok**. One portable `Cleanstrike.exe`: run it from anywhere, it finds the game, and you drop mods in and press Play.

- **Finds the game automatically** (Steam registry, every Steam library, common folders), or point it at the folder yourself.
- **Zero setup.** The first Play wires Cleanstrike into the game. "Remove Cleanstrike from the game" puts everything back, including any previous `override.cfg`.
- **Drag and drop install.** `.csmod`, `.vmz`, `.zip`, `.pck`. Badly packaged mods (the `mod.txt` one folder down, backslash paths) are repaired on install. Installing a newer version replaces the old one.
- **Load order and profiles.** Drag mods to reorder, toggle them on and off, and keep several setups.
- **Per-mod settings**, generated from the mod's `cleanstrike.settings.json`.
- **Launch report.** After you play, every mod shows whether it loaded, and if not, why, in plain language.
- **Safety nets.**
  - Mods made for another game version are held back.
  - A mod whose scripts don't compile is rolled back on its own, and the rest still load.
  - Two crashed boots in a row start the game without mods next time.
  - Creating an empty file named `Cleanstrike/disabled` in the game folder always boots vanilla.

## Repository

| Path | What |
|---|---|
| `app/Cleanstrike` | The Windows app (WPF, .NET 8) |
| `loader/cleanstrike_loader.gd` | The in-game loader (bundled into the app) |
| `mods/TarkovLooting` | **Tarkov Looting**: searching, unknown items/examining, Tarkov cell tints (standalone) |
| `mods/RoadToTarkov` | **Road to Tarkov (In Progress, paused)**: Customs map and travel; defers looting to Tarkov Looting when both are on |
| `maps/customs` | Customs map sources and generator (layout traced from re3mr) |
| `tests/SelfTest` | Headless in-game test harness (never ship) |
| `tests/AppTests` | App service tests that drive a real game folder |
| `tools/` | `build_mod.py`, `test.sh`, `publish.sh`, `make_icon.py` |
| `docs/MOD_FORMAT.md` | How to make a Cleanstrike mod |

## Building

```bash
tools/publish.sh          # dist/Cleanstrike.exe (portable) + dist/TarkovLooting.csmod + dist/RoadToTarkov.csmod
tools/test.sh             # end-to-end: app prepares a launch, game boots headless, mod self-test runs
MODS="TarkovLooting" tools/test.sh   # test one mod on its own
```

`test.sh` expects a copy of the game in `../TestGame` (`RTV.exe` + `RTV.pck`), or set `TESTGAME`.
Game files never go in this repository.

## How it works

Godot reads `override.cfg` next to the game's exe before anything else. Cleanstrike writes one that registers `Cleanstrike/loader.gd` as the very first autoload (`[autoload_prepend]`), plus each enabled mod's autoloads. The loader then does the rest:

1. Reads the load order the app wrote to `Cleanstrike/active.json`.
2. Checks each mod against the game version.
3. Mounts its archive.
4. Applies its script extensions.
5. Writes `%APPDATA%\Road to Vostok\cleanstrike\last_launch.json`, which the app reads back.

Script extensions use two strategies, because Godot behaves differently for scripts with a `class_name`. See [docs/MOD_FORMAT.md](docs/MOD_FORMAT.md).
