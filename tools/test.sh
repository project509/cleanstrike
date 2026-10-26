#!/usr/bin/env bash
# Build the mods, install them plus the loader into ../TestGame, run the game
# headless with the self-test harness, and print the results.
set -u
R="$(cd "$(dirname "$0")/.." && pwd)"
T="${TESTGAME:-$R/../TestGame}"
U="$APPDATA/Road to Vostok/cleanstrike"
# MODS: which mods to test with (default: every mod in mods/). E.g. MODS="TarkovLooting" tools/test.sh
MODS="${MODS:-$(cd "$R/mods" && for d in */; do [ -f "$d/mod.txt" ] && printf '%s ' "${d%/}"; done)}"
mkdir -p "$T/Cleanstrike/mods"
rm -f "$T/Cleanstrike/mods/"*.csmod
for m in $MODS; do
	python -I "$R/tools/build_mod.py" "$R/mods/$m" --out "$R/dist" --install "$T" >/dev/null || exit 1
done
echo "testing with: $MODS"
python -I "$R/tools/build_mod.py" "$R/tests/SelfTest" --out "$R/dist/test" --install "$T" >/dev/null || exit 1
# Two test mods that declare they can't run together (the loader must skip the second).
for c in ClashA ClashB; do python -I "$R/tools/build_mod.py" "$R/tests/ClashMods/$c" --out "$R/dist/test" --install "$T" >/dev/null || exit 1; done
# Prepare the launch with the app's own code (same as pressing Play), and
# run the app service checks along the way.
dotnet build "$R/tests/AppTests" -v q -nologo 2>&1 | grep -E " error " | sed 's/\[C:.*//' | sort -u
dotnet "$R/tests/AppTests/bin/Debug/net8.0-windows/AppTests.dll" "$(cygpath -w "$T")" "$(cygpath -w "$R/dist/apptest")" || { echo "app checks failed"; exit 1; }
rm -f "$U/selftest.json"
# The test game shares the real game's user folder. Snapshot the player's
# saves and Cleanstrike's mod data (e.g. examined items) and put them back
# afterwards; the test itself starts from empty mod data.
SAVES="$APPDATA/Road to Vostok"; SNAP="$R/dist/test/save_snapshot"
rm -rf "$SNAP"; mkdir -p "$SNAP/cs"; cp "$SAVES"/*.tres "$SNAP"/ 2>/dev/null
for f in data last_launch.json boot.json; do [ -e "$U/$f" ] && cp -r "$U/$f" "$SNAP/cs/"; done
rm -rf "$U/data"
(cd "$T" && timeout "${TIMEOUT:-1000}" ./RTV.exe --headless >"${GAMELOG:-/dev/null}" 2>&1); echo "game exit: $?"
for f in "$SAVES"/*.tres; do [ -e "$SNAP/$(basename "$f")" ] || rm -f "$f"; done
cp "$SNAP"/*.tres "$SAVES"/ && echo "player saves restored ($(ls "$SNAP"/*.tres | wc -l) files)"
cat "$U/cleanstrike.log"
L=$(ls -t "$APPDATA/Road to Vostok/logs"/godot*.log | head -1)
grep -A2 -E "SCRIPT ERROR|Parse Error" "$L" | head -40
[ -f "$U/selftest.json" ] && python -I -c "import json,sys;d=json.load(open(sys.argv[1]));[print('PASS' if r['ok'] else 'FAIL',r['name'],r['detail']) for r in d['results']];print('failures:',d['failures'])" "$U/selftest.json"
rm -rf "$U/data"; cp -r "$SNAP/cs/." "$U/" && echo "mod data restored"
# Leave TestGame playable: drop the self-test harness and test settings.
rm -f "$T/Cleanstrike/mods/SelfTest.csmod" "$T/Cleanstrike/mods/"cs_testclash_*.csmod "$T/Cleanstrike/mods/Clash"*.csmod "$T/Cleanstrike/settings/"*.json
dotnet "$R/tests/AppTests/bin/Debug/net8.0-windows/AppTests.dll" "$(cygpath -w "$T")" "$(cygpath -w "$R/dist/apptest")" prepare
