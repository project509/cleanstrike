#!/usr/bin/env bash
# Build the portable Cleanstrike.exe and the Road to Tarkov mod into dist/.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
dotnet publish "$R/app/Cleanstrike/Cleanstrike.csproj" -c Release -o "$R/dist/app" -v q -nologo
cp "$R/dist/app/Cleanstrike.exe" "$R/dist/Cleanstrike.exe"
python -I "$R/tools/build_mod.py" "$R/mods/RoadToTarkov" --out "$R/dist"
ls -la "$R/dist/Cleanstrike.exe" "$R/dist/RoadToTarkov.csmod"
