"""Create the standalone Tarkov Looting mod from Road to Tarkov's looting code.

Usage: python tools/extract_looting.py
Copies RTT.gd, SearchSpinner.gd and the looting script extensions into
mods/TarkovLooting, renaming paths/identifiers and dropping everything that
belongs to Customs (map tool, travel). Run once; afterwards Tarkov Looting is
developed on its own.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "mods", "RoadToTarkov", "RoadToTarkov")
DST_MOD = os.path.join(ROOT, "mods", "TarkovLooting")
DST = os.path.join(DST_MOD, "TarkovLooting")
os.makedirs(os.path.join(DST, "Ext"), exist_ok=True)


def convert(text: str) -> str:
    text = text.replace('preload("res://RoadToTarkov/RTT.gd")', 'preload("res://TarkovLooting/TL.gd")')
    text = text.replace("res://RoadToTarkov/", "res://TarkovLooting/")
    text = re.sub(r"\bRTT\.", "TL.", text)
    text = re.sub(r"\bconst RTT\b", "const TL", text)
    text = text.replace("RTT_", "TL_").replace("rtt_", "tl_")
    text = text.replace("Road to Tarkov", "Tarkov Looting")
    text = text.replace('"road_to_tarkov"', '"tarkov_looting"')
    return text


def cut_section(text: str, start_marker: str, end_marker: str) -> str:
    a = text.index(start_marker)
    b = text.index(end_marker, a)
    return text[:a] + text[b:]


# --- shared core: RTT.gd -> TL.gd, without the Customs settings
core = convert(open(os.path.join(SRC, "RTT.gd"), encoding="utf-8").read())
core = core.replace('const VERSION := "0.3.0"', 'const VERSION := "1.0.0"')
core = re.sub(r'\t"customs_enabled": true,\n', "", core)
core = re.sub(r'\t"customs_preview_button": true,\n', "", core)
core = re.sub(r"static func customs_enabled\(\) -> bool:\n\treturn .*\n\n\n", "", core)
core = re.sub(r"static func looting\(\) -> bool:\n(\t.*\n)+\n\n", "", core)
core = core.replace("TL.looting()", "active()")
core = re.sub(r"\blooting\(\)", "active()", core)
core = re.sub(r"# Looting features step aside[^\n]*\n# loaded \(it carries[^\n]*\n", "", core)
core = core.replace("# Tarkov Looting: shared state and helpers used by every script extension.",
                    "# Tarkov Looting: shared state and helpers used by every script extension.\n# (Extracted from Road to Tarkov; developed on its own from here.)")
open(os.path.join(DST, "TL.gd"), "w", encoding="utf-8", newline="\n").write(core)

spinner = convert(open(os.path.join(SRC, "SearchSpinner.gd"), encoding="utf-8").read())
open(os.path.join(DST, "SearchSpinner.gd"), "w", encoding="utf-8", newline="\n").write(spinner)

for name in ["Item", "LootContainer", "Pickup", "Tooltip", "Context", "Interface"]:
    text = open(os.path.join(SRC, "Ext", name + ".gd"), encoding="utf-8").read()
    text = re.sub(r"RTT\.looting\(\)", "RTT.active()", text)
    if name == "Interface":
        text = cut_section(text, "# ---------------------------------------------------------------- map tool",
                           "# ---------------------------------------------------------------- loop")
        text = text.replace("\tif RTT.active():\n\t\t_rtt_setup_map()\n", "")
    text = convert(text)
    assert "Customs" not in text, name + " still references Customs"
    open(os.path.join(DST, "Ext", name + ".gd"), "w", encoding="utf-8", newline="\n").write(text)

# --- manifest
open(os.path.join(DST_MOD, "mod.txt"), "w", encoding="utf-8", newline="\n").write('''[mod]
name="Tarkov Looting"
id="tarkov_looting"
version="1.0.0"
author="Cleanstrike"
description="Tarkov-style looting for Road to Vostok: search containers and bodies item by item, examine unknown items to identify them, and Tarkov-style inventory cells."
priority=10

[cleanstrike]
api=1
game_min="0.2.2.0"
godot_min="4.6.0"
tags=["UI", "Looting"]

; Order matters: Item first, Interface last (it preloads the item scene).
[script_extend]
res://Scripts/Item.gd="res://TarkovLooting/Ext/Item.gd"
res://Scripts/LootContainer.gd="res://TarkovLooting/Ext/LootContainer.gd"
res://Scripts/Pickup.gd="res://TarkovLooting/Ext/Pickup.gd"
res://Scripts/Tooltip.gd="res://TarkovLooting/Ext/Tooltip.gd"
res://Scripts/Context.gd="res://TarkovLooting/Ext/Context.gd"
res://Scripts/Interface.gd="res://TarkovLooting/Ext/Interface.gd"
''')

# --- settings: everything except the Customs ones
src_settings = json.load(open(os.path.join(ROOT, "mods", "RoadToTarkov", "cleanstrike.settings.json"), encoding="utf-8"))
settings = [s for s in src_settings["settings"] if not s["key"].startswith("customs")]
json.dump({"settings": settings}, open(os.path.join(DST_MOD, "cleanstrike.settings.json"), "w", encoding="utf-8", newline="\n"), indent=2)
print("Tarkov Looting written to", DST_MOD, "with", len(settings), "settings")
