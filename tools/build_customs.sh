#!/usr/bin/env bash
# Build the Customs map: layout.json -> prebuild data -> Godot scene in the
# recovered project -> copied into the mod. Needs C:\RTVDev (see docs/ROADMAP.md).
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
DEV="${RTVDEV:-/c/RTVDev}"
P="$DEV/RTVProject"
GODOT="$DEV/Godot/Godot_v4.6.3-stable_win64_console.exe"
DATA="$DEV/customs_build"
python -I "$R/maps/customs/prebuild.py" "$(cygpath -w "$R/maps/customs/layout.json")" "$(cygpath -w "$DATA")"
[ -f "$DATA/swatches/swatches.json" ] || python -I "$R/maps/customs/textures.py" "$(cygpath -w "$P")" "$(cygpath -w "$DATA/swatches")"
mkdir -p "$P/cs_tools/customs"
cp "$R/maps/customs/build_customs.gd" "$R/maps/customs/Builder.tscn" "$P/cs_tools/customs/"
rm -rf "$P/RoadToTarkov/Customs/Build"
timeout 1800 "$GODOT" --quit-after 900 --windowed --resolution 320x180 --position -4000,100 --path "$(cygpath -m "$P")" res://cs_tools/customs/Builder.tscn -- "$(cygpath -m "$DATA")" "$(cygpath -m "$R/maps/customs/layout.json")" 2>&1 | tee "$DEV/last_build.log" | grep -vE "^\s*$|Godot Engine|^WARNING: .*leaked|ObjectDB|resources still in use|^\s+at: " | tail -60
DST="$R/mods/RoadToTarkov/RoadToTarkov/Customs/Build"
grep -q "saved res://RoadToTarkov/Customs/Build" "$DEV/last_build.log" || { echo "BUILD FAILED"; exit 1; }
rm -rf "$DST"; mkdir -p "$DST"
cp -r "$P/RoadToTarkov/Customs/Build/." "$DST/"
mkdir -p "$P/RoadToTarkov/Customs"; cp "$R/mods/RoadToTarkov/RoadToTarkov/Customs/Customs.tscn" "$P/RoadToTarkov/Customs/"
du -sh "$DST"
