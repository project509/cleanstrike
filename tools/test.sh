#!/usr/bin/env bash
# Build the mods, install them plus the loader into ../TestGame, run the game
# headless with the self-test harness, and print the results.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
T="${TESTGAME:-$R/../TestGame}"
U="$APPDATA/Road to Vostok/cleanstrike"
# MODS: which mods to test with (default: both). E.g. MODS="TarkovLooting" tools/test.sh
MODS="${MODS:-TarkovLooting RoadToTarkov}"
mkdir -p "$T/Cleanstrike/mods"
rm -f "$T/Cleanstrike/mods/"*.csmod
for m in $MODS; do
	python -I "$R/tools/build_mod.py" "$R/mods/$m" --out "$R/dist" --install "$T" >/dev/null || exit 1
done
echo "testing with: $MODS"
python -I "$R/tools/build_mod.py" "$R/tests/SelfTest" --out "$R/dist/test" --install "$T" >/dev/null || exit 1
# Prepare the launch with the app's own code (same as pressing Play), and
# run the app service checks along the way.
dotnet build "$R/tests/AppTests" -v q -nologo 2>&1 | grep -E " error " | sed 's/\[C:.*//' | sort -u
dotnet "$R/tests/AppTests/bin/Debug/net8.0-windows/AppTests.dll" "$(cygpath -w "$T")" "$(cygpath -w "$R/dist/apptest")" || { echo "app checks failed"; exit 1; }
rm -f "$U/selftest.json" "$U/data/road_to_tarkov/knowledge.json" "$U/data/tarkov_looting/knowledge.json"
# Travel saves the character, so snapshot the player's saves and put them back afterwards.
SAVES="$APPDATA/Road to Vostok"; SNAP="$R/dist/test/save_snapshot"
rm -rf "$SNAP"; mkdir -p "$SNAP"; cp "$SAVES"/*.tres "$SNAP"/ 2>/dev/null
(cd "$T" && timeout "${TIMEOUT:-560}" ./RTV.exe --headless >/dev/null 2>&1); echo "game exit: $?"
for f in "$SAVES"/*.tres; do [ -e "$SNAP/$(basename "$f")" ] || rm -f "$f"; done
cp "$SNAP"/*.tres "$SAVES"/ && echo "player saves restored ($(ls "$SNAP" | wc -l) files)"
cat "$U/cleanstrike.log"
L=$(ls -t "$APPDATA/Road to Vostok/logs"/godot*.log | head -1)
grep -A2 -E "SCRIPT ERROR|Parse Error" "$L" | head -40
[ -f "$U/selftest.json" ] && python -I -c "import json,sys;d=json.load(open(sys.argv[1]));[print('PASS' if r['ok'] else 'FAIL',r['name'],r['detail']) for r in d['results']];print('failures:',d['failures'])" "$U/selftest.json"
rm -f "$U/data/road_to_tarkov/knowledge.json" "$U/data/tarkov_looting/knowledge.json"
# Leave TestGame playable: drop the self-test harness and test settings.
rm -f "$T/Cleanstrike/mods/SelfTest.csmod" "$T/Cleanstrike/settings/road_to_tarkov.json" "$T/Cleanstrike/settings/tarkov_looting.json"
dotnet "$R/tests/AppTests/bin/Debug/net8.0-windows/AppTests.dll" "$(cygpath -w "$T")" "$(cygpath -w "$R/dist/apptest")" prepare
