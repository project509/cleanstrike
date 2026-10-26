# Road to Tarkov: overhaul roadmap

> **Status: paused (In Progress).** Work has moved to the standalone Tarkov
> Looting mod (`mods/TarkovLooting`). Road to Tarkov defers its looting to it
> when both are enabled.

Goal: turn Road to Vostok into a faithful Escape from Tarkov experience.
That covers Tarkov's maps, UI, looting, raids, hideout, traders, quests and
progression, all built natively on Vostok so it looks and plays like a game
that was always meant to be this way.

## Ground rules

- **Homage, not rips.** We recreate Tarkov's layouts, mechanics, UI
  behaviour and feel. We never ship Battlestate Games' own files: no
  ripped audio, voices, textures, icons, logos or trader portraits.
  Everything is original, Vostok's own, or free-licensed (CC0 / CC-BY,
  credited).
- **Map blueprints** come from re3mr's fan maps (CC BY-NC-SA 4.0). Credit
  re3mr, never sell, and release adapted map art under the same licence.
- **Vostok-native.** Everything uses the game's own systems (LootContainer,
  AI, Transition, Recipes, Traders, Tasks) through Cleanstrike script
  extensions, so updates break as little as possible.
- **Tested in the real game.** Every feature gets `tests/SelfTest` checks;
  visuals get `tools/shots.sh` screenshots.

## Status

| # | Area | State |
|---|---|---|
| 1 | Container & body searching, unknown items, examine, Tarkov cell tints | **Done**, now the standalone **Tarkov Looting** mod (v1.0) |
| 2 | School / Customs destination picker, Customs routing, map tool | **Done** (v0.2) |
| 3 | Customs: full-scale map build | **In progress**: terrain, river, layout, Vostok buildings, generated warehouses, pipelines, fences, vehicles, forest, exits |
| 4 | Tarkov UI overhaul | Planned |
| 5 | Raids: timer, extracts, MIA/KIA, raid summary | Planned |
| 6 | Hideout: Cabin becomes Tarkov's underground hideout | Planned |
| 7 | Scav voice system | Planned |
| 8 | Traders, quests, skills | Planned |
| 9 | More maps (Factory, Woods, Interchange, Shoreline, Reserve…) | Planned |

## 3. Customs, full scale (~1.1 × 0.5 km)

Built in the recovered Godot 4.6.3 project (`C:\RTVDev\RTVProject`, never
committed), exported as part of the mod.

1. **Layout blockout.** Scale from re3mr's 100 m bar. Terrain sculpted to
   the landscape (river, embankments, construction pit, rail cut). Roads,
   railway, fences and gates traced from the map. Building volumes in place.
   Exits mapped to Vostok travel points. Playable end to end.
2. **Buildings.** Scripted in Blender with Vostok and CC0 materials: dorms
   (2- and 3-storey, full interiors), big red warehouse, old and new gas
   stations, factory shacks, construction site, crossroads, trailer park,
   fortress, boiler room, tank farm, USEC camp.
3. **Loot & AI.** Vostok loot containers at Tarkov's loot spots (marked rooms
   use keys). Scav spawns and patrols, a dorms boss with guards, navmesh.
4. **Dressing.** Vostok foliage, props, vehicles, lighting, ambient audio,
   weather. The in-game map is redrawn with Vostok exits.
5. **Polish.** Performance (occlusion, LODs), sight lines, cover, routes.

## 4. Tarkov UI overhaul

- Inventory: stash, gear and character panels laid out like Tarkov. Item
  cells with background colours, short names, stack counts and FIR marks.
  Ctrl/Shift/Alt click behaviour matches Tarkov. Inspect window. Sorting
  table.
- Health screen with body parts mapped to Vostok's conditions.
- Raid flow screens: location select, then insurance, then ready. A
  post-raid summary (Survived / Run-through / MIA / KIA, kills, loot, XP).
- In raid: a double-tap key shows time left and your extracts. Stamina and
  hand-stamina bars.
- Original Tarkov-style UI sounds (zips, clicks, search loop).

## 5. Raids

- Raid timer per map. MIA when it runs out (you lose your gear, like dying).
- Extracts: always-open, conditional (pay, switch, no backpack), random,
  and scav-only. They map onto Vostok travel points and shelters.
- Found-in-raid status on items picked up in a raid. Insurance with a
  return timer (optional).

## 6. Hideout (replaces the Cabin)

An underground bunker laid out like Tarkov's Hideout, with upgradeable
stations. Upgrades need items and time, and each gives passive bonuses or
crafts through Vostok's recipe system:

Generator, Air filtering, Vents, Heating, Illumination, Water collector,
Lavatory, Medstation, Nutrition unit, Workbench, Intelligence center, Rest
space, Library, Shooting range, Security, Stash (sizes), Scav case,
Bitcoin farm, Booze generator, Solar power.

## 7. Scav voice system

Context barks on Vostok's AI: idle chatter, spotted enemy, reloading,
grenade, hit, dying, and friendly scav call-outs. It ships with an original
Russian line script (`docs/voice-script.md`, to come) and slots for
recordings. The voices themselves come from our own or licensed
performances, never Tarkov's.

## 8. Traders, quests, skills

- Traders: Tarkov-style buy/sell, loyalty levels and barters on Vostok's
  trader system. Characters are original analogues, not Battlestate's.
- Quests: Tarkov-like task chains through Vostok's tasks (find in raid,
  hand over, mark, survive and extract).
- Skills that level by doing: Search (faster searching, which plugs into
  feature 1), Attention (faster examining), Endurance, Strength, Vitality,
  Metabolism, Covert movement, Weapon handling.

## 9. More maps

In order: Factory (small, a good second), Woods, Interchange, Shoreline,
Reserve, Lighthouse, Streets. Each one needs a School-style picker entry or
a Vostok travel hook.
