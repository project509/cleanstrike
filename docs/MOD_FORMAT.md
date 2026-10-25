# Making a Cleanstrike mod

A mod is a zip archive (extension `.csmod`, though `.vmz`/`.zip` work too) with `mod.txt` at its root. The format is compatible with the community `mod.txt` used by Metro Mod Loader / VostokMods, plus a `[cleanstrike]` section.

```
MyMod.csmod
  mod.txt
  cleanstrike.settings.json     (optional: settings shown in the app)
  MyMod/                         mounts as res://MyMod/...
    Main.gd
    Ext/Interface.gd
```

Build with `python tools/build_mod.py mods/MyMod`. It checks the manifest and writes forward-slash paths. Godot can't mount zips with backslash paths, which is what .NET's `ZipFile.CreateFromDirectory` produces on Windows.

## mod.txt

```ini
[mod]
name="My Mod"
id="my_mod"                 ; unique, never change it (settings and profiles key off it)
version="1.0.0"
author="You"
description="One or two sentences shown in the app."
priority=0

[cleanstrike]
api=1                       ; loader API this mod needs
game_min="0.2.2.0"          ; optional: oldest game version supported
game_max=""                 ; optional: newest game version supported
godot_min="4.6.0"           ; optional
tags=["UI", "Looting"]

[script_extend]             ; order matters, see below
res://Scripts/Item.gd="res://MyMod/Ext/Item.gd"
res://Scripts/Interface.gd="res://MyMod/Ext/Interface.gd"

[autoload]                  ; created right after the game's own singletons
MyMod="res://MyMod/Main.gd"

[dependencies]
required=["other_mod_id"]   ; must be enabled and earlier in the load order
```

All string values must be quoted.

## Script extensions

An extension script must start with `extends "<the vanilla path>"` and override methods, calling `super(...)` where the original behaviour should still happen:

```gdscript
extends "res://Scripts/Interface.gd"

func Open():
    super()
    # your code
```

The loader picks one of two strategies per script:

| Vanilla script | Strategy | Notes |
|---|---|---|
| no `class_name` (e.g. `Interface.gd`, `Tooltip.gd`) | path takeover | Every later load of the path returns your script. Several mods can chain on the same script. |
| has a `class_name` (e.g. `Item`, `LootContainer`, `Pickup`) | node swap | Nodes using the vanilla script get yours as they enter the tree, keeping their variables. Taking over these paths breaks `is ClassName` checks across the game, so this path is never used for them. If two mods extend the same class script, the later one wins (logged). |

**Order matters.** List leaf scripts (like `Item.gd`) before scripts that preload scenes using them (like `Interface.gd`).

Each mod is **all or nothing**. If any of its extensions fails to compile against the player's game version, its other extensions are rolled back and the app shows the reason. Write extensions defensively; game updates rename things.

**Runtime errors are silent** in the shipped game (it's a release build), so test your code paths, and print progress while debugging.

## Talking to Cleanstrike

From any script:

```gdscript
var cs = Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null
if cs:
    cs.is_loaded("my_mod")                       # false if your mod was rolled back: stay vanilla
    cs.get_setting("my_mod", "speed", 1.0)       # values from the app's settings panel
    cs.get_data_dir("my_mod")                    # user://cleanstrike/data/my_mod (for your save data)
    cs.log_message("my_mod", "hello")            # goes to the launch log
```

Autoloads registered in `[autoload]` run even if your script extensions were rolled back, so check `is_loaded()` first.

## Settings (`cleanstrike.settings.json`)

```json
{
  "settings": [
    { "key": "enabled", "type": "bool", "default": true, "label": "Turn it on", "description": "Shown under the label." },
    { "key": "speed", "type": "float", "default": 1.0, "min": 0.25, "max": 4.0, "step": 0.25, "label": "Speed" },
    { "key": "count", "type": "int", "default": 3, "min": 1, "max": 10, "step": 1, "label": "Count" },
    { "key": "mode", "type": "choice", "default": "Classic", "options": ["Classic", "Hardcore"], "label": "Mode" },
    { "key": "tag", "type": "string", "default": "", "label": "Tag" }
  ]
}
```

The app saves values to `<game>/Cleanstrike/settings/<id>.json`, and they apply on the next launch.

## Testing

`tools/test.sh` builds the mods and prepares a launch through the app's own code. It then boots the game headless with `tests/SelfTest`, which loads a map and drives the UI through the mod's features. Copy that harness to test your own mod.
