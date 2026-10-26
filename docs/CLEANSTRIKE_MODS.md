# Cleanstrike mods: lineup, specs and status

Cleanstrike is a walled garden: every mod is made by the Cleanstrike team and
ships inside the app. Where the community made a popular mod, we build our own
version that behaves the same, written from scratch. Specs below come only
from the original mods' public pages (description, changelog, settings,
author replies); never from their code or files.

Premium mods (gold frame in the app): Road to Tarkov, Tarkov Looting,
CleanStrike Fixes Overhaul.

Game target: Road to Vostok 0.2.2.0 (Build 2). Most originals were written
for 0.1.x (Build 1); where Build 2 changed things, we follow the game.

## Status

| # | Cleanstrike mod | id | Status |
|---|---|---|---|
| 1 | No Permadeath | cs_no_permadeath | Done (1.0.0) |
| 2 | Better Traders | cs_better_traders | Done (1.0.0) |
| 3 | Loot Settings, Better Enemy Loot | cs_loot_settings, cs_better_enemy_loot | Done (1.0.0) |
| 4 | Event Hints | cs_event_hints | Done (1.0.0) |
| 5 | Focus Zoom, Hold Breath | cs_focus_zoom, cs_hold_breath | Done (1.0.0) |
| 6 | CleanStrike Fixes Overhaul (premium) | cs_fixes_overhaul | Done (1.0.0) |
| 7 | Medical Durability | cs_medical_durability | Done (1.0.0) |
| 8 | Gear Spawns | cs_gear_spawns | Done (1.0.0) |
| | Tarkov Looting (premium) | tarkov_looting | Done (1.2.0) |
| | Road to Tarkov (premium) | road_to_tarkov | Paused |

The full 43-mod lineup (from ModWorkshop's 80 most-downloaded mods) is in
the conversation record and will be added here as each wave is started.

---

## 1. No Permadeath (done)
Sources: No More Permadeath (TellTaleSpider, mod/56015), No Gear Loss on Death
(JoeVostok, mod/53307; Build 2 fork by smel, mod/59303), No Permadeath
(Purplefin Neptuna, mod/49786).
- Vostok-zone deaths (Apartments, Terminal, Airfield) work like normal deaths:
  gear lost, respawn at the last shelter, saves kept. Setting `zones` (on).
- Hardcore (difficulty 3, every map permadeath): same, setting `hardcore` (on).
  No More Permadeath left Hardcore alone; smel's fork covers it.
- `on_death`: Lose everything (vanilla) / Keep worn gear and weapons / Keep
  everything (inventory + furniture catalog). Respawn at full health.
- `keep_on_quit`: quitting outside a shelter normally resets the character
  (with a warning); with this on it's saved instead and no warning shows.
- HUD skull icon and "Permadeath Zone" travel hint hidden when spared.
Hooks: Character.Death, Settings exit buttons, HUD.

## 2. Better Traders
Sources: Trader Tabs (Romero, mod/56550 + vostokmods.net Build 2 page),
Trader Improvements (tetrahydroc, mod/55972), Trader Refresh Hotkey
(Purple_Heart, mod/55155).
- Tabs: Goods / Furniture (furniture grid larger, scrollable) / Stock.
- Stock tab: trader-specific assortment by reputation tier = tasks completed.
  5 tiers (tier 1 at 0 tasks, tier 5 at all tasks); 3 random items per
  unlocked tier on each resupply (tier 1 = 3 items ... tier 5 = 15); better
  pools per tier; "Stock Tier" label; popup on tier-up.
- Special keys from Stock at tier 3: Generalist's Cellar Key, Doctor's
  Gymnasium Key, Gunsmith's Tunnel Key, 3000 each (work like the real keys,
  never in loot). (Must not break saves if the mod is removed.)
- Trader rep levels: Unknown, Acquaintance, Trusted, Reliable, Valued,
  Partner (0-5) with a label like "Reliable (46)"; daily tasks 1-6 by rep
  ("Bring me 2x ... and I'll give you 1x ...", Complete Daily, Completed
  today; difficulty Simple/Easy/Moderate/Challenging); permanent stock;
  repairs (Doctor: armor, Gunsmith: guns).
- Refresh: hotkey (default F1) forces an immediate resupply; optional
  cooldown (users used 30 min).
- Settings: stock tab on/off; grid rows per tab; refresh key; cooldown.
Vanilla: Trader.gd supply = 40 random items from the trader's bucket every
`traderData.resupply` minutes; Interface.FillSupplyGrid / Resupply.
Built (1.0.0): reputation 0-5 (thresholds 0/10/25/45/70/100; 10 per task,
dailies 2-6.5, 1 per 1000 traded; resets on FormatSave); Stock = 3 per level
from 6 value bands of the trader's range, + key at Reliable (3000, the
game's own keys so removal can't break saves); dailies = 1 + level, the
last a kill contract from Acquaintance; repairs priced at missing% x value
x 0.5 x (1 + tax/200), paid like a deal; restock hotkey F1 + cooldown.

## 3. Loot Settings + Better Enemy Loot
Loot Settings sources: Loot Modifier (False_Hope, mod/56036, Build 2), Mega
Loot (BitByteBytes, mod/56257), Loot Overhaul (ErikDoesGaming, mod/57120).
- Vanilla defaults unchanged unless set: container chances common 0.25 /
  rare 0.05 / legendary 0.001; joker 1%; items min 1 max 5; floor loot same
  chances; floor re-roll 0.5; spawn condition 25-100.
- Extras: re-roll when a container rolls nothing; chance to add a guaranteed
  amount (min..max) of items; legendary items allowed in joker crates; item
  weights (default even within a rarity).
- Presets: Vanilla / Loot Overhaul (70% of containers have something, at
  least 1 item, rare more likely alongside common, more medical) / Mega Loot
  (more loot everywhere, every special crate on the map, legendary in special
  crates, more keys, no empty cans).
Better Enemy Loot (Bearshades, mod/56230):
- Killed AI get extra loot added (never replaced): Ammo (Normal: lowest of
  2 rolls 0..10), Consumables (Normal, max 2), Magazines for their weapon
  (Low: lowest of 3 rolls, max 2), Medical (Low, max 2); rare chance 0.25.
- Bandits civilian loot only; Vostok military: military/industrial/civilian.
Vanilla: LootContainer.GenerateLoot (rarity roll 1..100, corpses 1..30),
CreateLoot; AI.Death enables the corpse container.
Built (1.0.0): Loot Settings presets Vanilla / Balanced (default) / Loot
Overhaul / Mega Loot / Custom, same roll for containers and floor loot
(LootSimulation); verified: game-equivalent 80.5% empty, Balanced 50.6%,
Loot Overhaul 70.5% non-empty, Mega 4.7 items. Better Enemy Loot adds to
the corpse container on AI.Death: ammo (weaponData.ammo), magazines
(compatible[0]), consumables, medical; faction filters; amounts
None/Low/Normal/More/Lots. Game bug noted for Fixes: LootSimulation with a
custom table and no force never spawns its items.

## 4. Event Hints (+ configs)
Source: Event Hints (notyme, mod/55994; vostokmods.net 0.3.2, tested 0.2.2.0).
- Hint shown on entering a map where an event is active (e.g. Punisher:
  "You can hear distant police sirens..."); per-event hint toggles; Bogeyman
  night hint.
- Per event: success chance (vanilla defaults Airdrop 15, Crash Sites 15,
  Punisher 15, Bogeyman 15, Attack Helicopter 25, BTR 25, Fighter Jet 25),
  selection weight (default 1, 0 = never), max delay for non-instant events
  (300 s).
- One event per map visit, picked by weight; calendar unlock days and night
  rules respected.
Vanilla: EventSystem.ActivateDynamicEvent picks one available dynamic event
uniformly, then succeeds if randi_range(0, 100) <= possibility.
Built (1.0.0): per-event chance (written into the EventData so the game's
Events panel shows it), weight, hint toggle; max delay; our own hint texts.
Fair odds (one roll over all events, >=20% quiet) live here and switch on
when CleanStrike Fixes Overhaul is loaded with its event_odds fix.

## 5. Focus Zoom + Hold Breath
Focus Eye (Gugluv, mod/55962):
- Hold a key (keyboard or mouse) to narrow FOV: focus 1.8x, while sprinting
  1.3x ("adrenaline"), ADS on iron/1x sights 1.2x; sensitivity scaled with
  FOV (atan focal-length scaling); toggles: zoom while ADS, zoom while scoped
  (first level only), allow in shelters; not while placing items or with the
  inventory open. No zoom with magnified/PIP scopes.
Hold Breath (tetrahydroc, mod/55938):
- While aiming, hold Shift: much less sway for a short time at the cost of
  faster arm-stamina drain; rebindable. (No numbers published; we tune.)
Built (1.0.0): Focus Zoom hooks Camera.FOV (target = game's FOV / 1.8 focus,
/1.3 sprinting, /1.2 ADS on non-magnified sights; key Mouse4 or any key;
hold or toggle) and Controller._input (sensitivity x tan(fov/2)/tan(base/2)).
Hold Breath hooks Noise.gd (weapon sway): sway x0.25 while held (sprint key
while aiming), arm stamina -8/s, max 8 s then 3 s catching breath at x1.6.

## 6. CleanStrike Fixes Overhaul (premium)
Fixes from mods: Fixed Doors (mod/56381: doors swing away from the player,
moving/open doors don't block you, opening door stops at obstacles), Trader
Lag Fix (mod/56270: no shadows from trader-area lights/meshes; do it at
runtime, never remap trader files), Fix Event Probability (mod/56355 and
mod/59412: one roll over all events so stated chances are real; Build 2
Outpost sums to 110%), Overlapping Effect Areas Fix (mod/56219: indoor + fire
+ workbench + heat all apply at once; Detector.Detect).
Candidate game bugs (Steam discussions, Oct 2026): AI night sight overridden
by fog (Sensor.gd order), furniture deleted when the catalog is full, decor
mode soft-lock with no valid spot, items floating/lost after drags,
magazines from storage dropping when there is room, tooltip closing on 1 px
move, looted containers not marked empty, first-shot hitch (preload hit
decals), crafting category stutter, items falling through shelter
furniture, stuck-in-geometry (unstuck), trader task crash exploit.

## 7. Medical Durability
Source: ragnarito, mod/56037. Uses per item: Bandage_Improvised 2, Bandage 3,
Splint_Improvised 2, Splint 3, Tourniquet_Improvised 3, Tourniquet 5,
Painkillers 6, Antibiotics 4, Antiseptic 5, IFAK 6, AFAK 7, Cold_Medicine 4,
Lotion 4, Balm 4, Melatonin 6, Wipes 8, Tissues 8, Deodorant 10, Saline 2,
Medkit 8. Remaining uses replace the % in the cell corner; per-item settings;
looted items spawn partly used, traders sell full. Must call the game's Use
(the original broke other mods by not doing so) and fix its reported bugs
(shared counts in storage, 0-use spawns, crafting eating the whole item,
partial items stacking).

## 8. Gear Spawns
Weapon Attachment Spawner (Peter Master, mod/56354): world, container and
enemy weapons get magazines and attachments. d100 per category against a
faction chance, weighted pick (0 = never), rare bias. Defaults: Bandit scope
10 / suppressor 5 / laser 8; Guard 20/10/15; Military 40/20/30; world 8/4/6;
world magazine chance 40% filled 5-80%; unlock days scope 10, suppressor 30,
laser 5 (2% before unlock); chamber modes; rare bias bandit 0.5, guard 1.0,
military 2.0, world 0.3.
Night Vision Spawner (mod/56388): at night AI may carry flashlights (bandit
20 / guard 40 / military 60%), NVG (0 / 5 / 30%), lasers (30 / 50 / 70%);
sight boost 20 / 35 / 60; NVG wearers drop a PV7 with random battery;
flashlights blink on 8-20 s / off 3-10 s, off on death.

## Wave 2 (build in this order; research each original's public page first)
1. Immortal Cat  2. Infinite Bedding  3. Kill Counter  4. Save Anywhere
5. Scope Sensitivity  6. Burst Fire  7. Better Lean  8. Weapon Position
9. Hideout Lights  10. Airdrops (red smoke)  11. Heli Go Boom  12. Sound Indicators
13. Item Clarity  14. Loot Highlight  15. Cash Money  16. Clothes to Rags
17. Multi-Use Items  18. Injuries Rework  19. Everything Lootable  20. Better Map
21. Better Inventory and Equipment  22. HUD  23. Tactical Watch  24. Custom Fonts
25. Reticles  26. Weather and Seasons  27. Death and Hit Effects  28. Faction Warfare
29. AI Overhaul  30. Progression  31. Shelters  32. Visuals  33. Sandbox Mode
Status: wave 1 (8 mods) done; wave 2: Immortal Cat, Infinite Bedding, Kill Counter, Save Anywhere, Scope Sensitivity, Burst Fire, Better Lean, Weapon Position, Airdrops, Heli Go Boom done.
Hideout Lights moved next to Shelters: the original (mod/56519) adds 9 placeable
light fixtures from vanilla lamp assets, sold by traders; that needs new furniture
items (F scene, icon, Database entry via _get), the same groundwork Shelters needs.

## Queued after the lineup
- CleanStrike Zombies (premium): replaces all enemies with sound-aware zombie packs
  (model + Mixamo animations in ideaboard/), dismemberment, crawlers, door breaking
  (10 hits), loot chance, aggro loss after 3 min unseen.
- CleanStrike Weapons Pack (premium): v1 = FN SCAR (asset in ideaboard/), fully
  compatible with vanilla attachments and systems.
