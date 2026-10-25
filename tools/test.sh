#!/usr/bin/env bash
# Build the mods, install them plus the loader into ../TestGame, run the game
# headless with the self-test harness, and print the results.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
T="${TESTGAME:-$R/../TestGame}"
U="$APPDATA/Road to Vostok/cleanstrike"
python -I "$R/tools/build_mod.py" "$R/mods/RoadToTarkov" --out "$R/dist" --install "$T" >/dev/null || exit 1
python -I "$R/tools/build_mod.py" "$R/tests/SelfTest" --out "$R/dist" --install "$T" >/dev/null || exit 1
# Prepare the launch with the app's own code (same as pressing Play), and
# run the app service checks along the way.
dotnet build "$R/tests/AppTests" -v q -nologo 2>&1 | grep -E " error " | sed 's/\[C:.*//' | sort -u
dotnet "$R/tests/AppTests/bin/Debug/net8.0-windows/AppTests.dll" "$(cygpath -w "$T")" "$(cygpath -w "$R/dist/apptest")" || { echo "app checks failed"; exit 1; }
rm -f "$U/selftest.json" "$U/data/road_to_tarkov/knowledge.json"
(cd "$T" && timeout "${TIMEOUT:-300}" ./RTV.exe --headless >/dev/null 2>&1); echo "game exit: $?"
cat "$U/cleanstrike.log"
L=$(ls -t "$APPDATA/Road to Vostok/logs"/godot*.log | head -1)
grep -A2 -E "SCRIPT ERROR|Parse Error" "$L" | head -40
[ -f "$U/selftest.json" ] && python -I -c "import json,sys;d=json.load(open(sys.argv[1]));[print('PASS' if r['ok'] else 'FAIL',r['name'],r['detail']) for r in d['results']];print('failures:',d['failures'])" "$U/selftest.json"
rm -f "$U/data/road_to_tarkov/knowledge.json"
# Leave TestGame playable: drop the self-test harness and test settings.
rm -f "$T/Cleanstrike/mods/SelfTest.csmod" "$T/Cleanstrike/settings/road_to_tarkov.json"
dotnet "$R/tests/AppTests/bin/Debug/net8.0-windows/AppTests.dll" "$(cygpath -w "$T")" "$(cygpath -w "$R/dist/apptest")" prepare
