# Development notes

- **Never launch the game or the Cleanstrike window in the foreground for development** unless the owner asks to see it. Run everything hidden or in the background:
  - in-game tests: `tools/test.sh` (game runs `--headless`)
  - screenshots: `tools/shots.sh` (window off-screen, unfocusable)
  - installing into the real game: `dist/Cleanstrike.exe <mod files> --silent`
  - app screenshots: `dist/Cleanstrike.exe --screenshot out.png`
- Player saves are snapshotted and restored by the test scripts; never touch them otherwise.
- Cleanstrike mods are our own clean-room implementations; never copy other mods' code or assets.
