#!/usr/bin/env bash
# Build Cleanstrike's mods, then the portable Cleanstrike.exe with those mods
# bundled inside it (installed automatically on first run). Output: dist/.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$R/dist/bundled"; mkdir -p "$R/dist/bundled"
for m in TarkovLooting RoadToTarkov; do
	python -I "$R/tools/build_mod.py" "$R/mods/$m" --out "$R/dist"
	cp "$R/dist/$m.csmod" "$R/dist/bundled/"
done
dotnet publish "$R/app/Cleanstrike/Cleanstrike.csproj" -c Release -o "$R/dist/app" -v q -nologo
cp "$R/dist/app/Cleanstrike.exe" "$R/dist/Cleanstrike.exe"
ls -la "$R/dist/Cleanstrike.exe" "$R/dist/"*.csmod
