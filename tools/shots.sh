#!/usr/bin/env bash
# Render real in-game screenshots of the mod's UI into dist/shots/.
# Runs the game windowed but off-screen and unfocusable (never on the desktop). Player saves are
# snapshotted and restored.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
T="${TESTGAME:-$R/../TestGame}"
U="$APPDATA/Road to Vostok"
# MODS: mods to render with. SHOTS=<mode> renders one UI instead of the maps
# (loot: Tarkov Looting's inventory views; trader: the trader screen).
MODS="${MODS:-RoadToTarkov}"; [ "${SHOTS:-}" = loot ] && MODS="${MODS/RoadToTarkov/TarkovLooting}"
rm -f "$T/Cleanstrike/mods/"*.csmod
for m in $MODS; do python -I "$R/tools/build_mod.py" "$R/mods/$m" --out "$R/dist" --install "$T" >/dev/null || exit 1; done
rm -f "$U/cleanstrike/"shot_mode_*; [ -n "${SHOTS:-}" ] && touch "$U/cleanstrike/shot_mode_$SHOTS"
python -I "$R/tools/build_mod.py" "$R/tests/Shots" --out "$R/dist/test" --install "$T" >/dev/null || exit 1
cp "$R/loader/cleanstrike_loader.gd" "$T/Cleanstrike/loader.gd"
cp "$T/override.cfg" "$R/dist/test/override.bak"; mv "$T/Cleanstrike/active.json" "$R/dist/test/active.bak" 2>/dev/null
printf '; Managed by Cleanstrike (shots.sh)\n[display]\nwindow/size/no_focus=true\n\n[autoload_prepend]\nCleanstrike="*res://Cleanstrike/loader.gd"\n\n[autoload]\nCSShot="*res://Shot/Runner.gd"\n' > "$T/override.cfg"
SNAP="$R/dist/test/save_snapshot"; rm -rf "$SNAP"; mkdir -p "$SNAP/cs"; cp "$U"/*.tres "$SNAP"/
# Mod data (e.g. examined items) is the player's too: keep a copy, start the shots from empty.
for f in data last_launch.json boot.json; do [ -e "$U/cleanstrike/$f" ] && cp -r "$U/cleanstrike/$f" "$SNAP/cs/"; done
rm -rf "$U/cleanstrike/data"
rm -f "$U/cleanstrike/"shot_*.png
(cd "$T" && timeout 600 ./RTV.exe --windowed --resolution 1920x1080 --position -4000,100 > "${GAMELOG:-/dev/null}" 2>&1)
for f in "$U"/*.tres; do [ -e "$SNAP/$(basename "$f")" ] || rm -f "$f"; done
cp "$SNAP"/*.tres "$U"/
rm -f "$T/Cleanstrike/mods/Shots.csmod" "$U/cleanstrike/"shot_mode_*
rm -rf "$U/cleanstrike/data"; cp -r "$SNAP/cs/." "$U/cleanstrike/"
cp "$R/dist/test/override.bak" "$T/override.cfg"; mv "$R/dist/test/active.bak" "$T/Cleanstrike/active.json" 2>/dev/null
mkdir -p "$R/dist/shots"; mv "$U/cleanstrike/"shot_*.png "$R/dist/shots/" 2>/dev/null
ls "$R/dist/shots"
