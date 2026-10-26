"""Scaffold a new Cleanstrike mod.

Usage: python tools/new_mod.py <Folder> <mod_id> "<Display name>" "<description>" [tag ...]
e.g.   python tools/new_mod.py NoPermadeath cs_no_permadeath "No Permadeath" "Dying never deletes your saves." Survival

Creates:
  mods/<Folder>/mod.txt, cleanstrike.settings.json
  mods/<Folder>/CS<Folder>/Mod.gd          shared helpers (settings, Cleanstrike API)
  tests/SelfTest/CSTest/Mods/<Folder>.gd   self-test stub, registered in Runner.gd
The mod's files mount at res://CS<Folder>/.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    folder, mod_id, name, desc = sys.argv[1:5]
    tags = sys.argv[5:]
    res = "CS" + folder
    mod_dir = os.path.join(ROOT, "mods", folder)
    if os.path.exists(mod_dir):
        sys.exit(f"{mod_dir} already exists")
    os.makedirs(os.path.join(mod_dir, res, "Ext"))

    def write(path, text):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

    tag_list = ", ".join(f'"{t}"' for t in tags)
    write(os.path.join(mod_dir, "mod.txt"), f'''[mod]
name="{name}"
id="{mod_id}"
version="1.0.0"
author="Cleanstrike"
description="{desc}"
priority=0

[cleanstrike]
api=1
game_min="0.2.2.0"
godot_min="4.6.0"
tags=[{tag_list}]

[script_extend]
''')
    write(os.path.join(mod_dir, "cleanstrike.settings.json"), json.dumps({"settings": []}, indent=2) + "\n")
    write(os.path.join(mod_dir, res, "Mod.gd"), f'''# {name}: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "{mod_id}"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {{
}}

# Self-test hook: values here win over the player's settings.
static var overrides := {{}}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# False when Cleanstrike rolled this mod back: stay vanilla.
static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	if overrides.has(key):
		return overrides[key]
	var fallback = DEFAULTS.get(key)
	var c := cs()
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	if typeof(v) == typeof(fallback) or (typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT):
		return v
	return fallback


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])
''')
    test_path = os.path.join(ROOT, "tests", "SelfTest", "CSTest", "Mods", folder + ".gd")
    os.makedirs(os.path.dirname(test_path), exist_ok=True)
    write(test_path, f'''# Self-test for {name} ({mod_id}). r is the CSTest runner (r.check, r.wait, ...).
extends RefCounted

const M = preload("res://{res}/Mod.gd")


func run(r) -> void:
	r.check("{folder}: active", M.active())
''')
    runner = os.path.join(ROOT, "tests", "SelfTest", "CSTest", "Runner.gd")
    s = open(runner, encoding="utf-8").read()
    entry = f'\t"{mod_id}": "res://CSTest/Mods/{folder}.gd",\n'
    s = re.sub(r"(const MOD_TESTS := \{\n)", lambda m: m.group(1) + entry, s, count=1)
    write(runner, s)
    print(f"created mods/{folder} (res://{res}/) and its self-test")


if __name__ == "__main__":
    main()
