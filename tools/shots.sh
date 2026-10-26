#!/usr/bin/env bash
# Render real in-game screenshots of the mod's UI into dist/shots/.
# Runs the game windowed but off-screen for ~30 s. Player saves are
# snapshotted and restored.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
T="${TESTGAME:-$R/../TestGame}"
U="$APPDATA/Road to Vostok"
# MODS: mods to render with. SHOTS=loot renders Tarkov Looting's inventory views instead of maps.
MODS="${MODS:-RoadToTarkov}"; [ "${SHOTS:-}" = loot ] && MODS="${MODS/RoadToTarkov/TarkovLooting}"
rm -f "$T/Cleanstrike/mods/"*.csmod
for m in $MODS; do python -I "$R/tools/build_mod.py" "$R/mods/$m" --out "$R/dist" --install "$T" >/dev/null || exit 1; done
rm -f "$U/cleanstrike/shot_loot"; [ "${SHOTS:-}" = loot ] && touch "$U/cleanstrike/shot_loot" && rm -f "$U/cleanstrike/data/tarkov_looting/knowledge.json"
python -I "$R/tools/build_mod.py" "$R/tests/Shots" --out "$R/dist/test" --install "$T" >/dev/null || exit 1
cp "$R/loader/cleanstrike_loader.gd" "$T/Cleanstrike/loader.gd"
cp "$T/override.cfg" "$R/dist/test/override.bak"; mv "$T/Cleanstrike/active.json" "$R/dist/test/active.bak" 2>/dev/null
printf '; Managed by Cleanstrike (shots.sh)\n[autoload_prepend]\nCleanstrike="*res://Cleanstrike/loader.gd"\n\n[autoload]\nCSShot="*res://Shot/Runner.gd"\n' > "$T/override.cfg"
SNAP="$R/dist/test/save_snapshot"; rm -rf "$SNAP"; mkdir -p "$SNAP"; cp "$U"/*.tres "$SNAP"/
rm -f "$U/cleanstrike/"shot_*.png
(cd "$T" && timeout 600 ./RTV.exe --windowed --resolution 1920x1080 --position -4000,100 >/dev/null 2>&1)
for f in "$U"/*.tres; do [ -e "$SNAP/$(basename "$f")" ] || rm -f "$f"; done
cp "$SNAP"/*.tres "$U"/
rm -f "$T/Cleanstrike/mods/Shots.csmod" "$U/cleanstrike/shot_loot" "$U/cleanstrike/data/tarkov_looting/knowledge.json"
cp "$R/dist/test/override.bak" "$T/override.cfg"; mv "$R/dist/test/active.bak" "$T/Cleanstrike/active.json" 2>/dev/null
mkdir -p "$R/dist/shots"; mv "$U/cleanstrike/"shot_*.png "$R/dist/shots/" 2>/dev/null
ls "$R/dist/shots"
