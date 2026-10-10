# Hero Arena — custom co-op map (Warcraft III 1.26a)

Source branch: `govno`. Work branch: `feature/hero-arena-expanded`.

**IMPORTANT:** This repository contains unpacked Warcraft III map contents. It is not itself a playable `.w3x`. Pack all `war3map.*` files (including the newly added `war3map.w3u`, `war3map.w3a`, and `war3map.w3t`) inside one classic Warcraft III map archive. Replacing only `war3map.j` will not load any custom heroes, shops, abilities or items.

## Hero selection
Move your Wisp to one of the six statue platforms in the north; alternatively type `-pick 1` through `-pick 6`. After 90 seconds unpicked heroes are randomized. Waves begin 15 seconds after selection completes.

## Six unique heroes

| Hero name | Epithet | Class | Signature abilities |
|---|---|---|---|
| Reynar Lightforged | Guardian of the Last Dawn | Strength tank/support | Spear of Judgment (A101), Oath of Dawn (A102) |
| Zarkhan Swiftwing | Dancer Among the Sands | Agility melee | Sand Rift (A103), Shadow Dance (A104) |
| Mirella Sparkborn | Whisperer to the Storms | Intellect mage | Needle Storm (A105), Storm Guardian (A106) |
| Morven Ashbringer | Heir to a Forgotten Throne | Strength bruiser | Touch of Ash (A107), Grave Winter (A108) |
| Valtir Faceless | Wanderer Between Worlds | Agility assassin | Rift Step (A109), Void Fire (A10A) |
| Selena Stargazer | Last Daughter of the Night | Ranged intellect-support hybrid | Moon Judgment (A10B), Starfall (A10C) |

Each has a custom Object Editor unit (`H001`, `O001`, `H002`, `U001`, `E001`, `E002`) with different STR, AGI, INT, growth, HP, mana and movement speed. Native proper names and tooltips are custom. Floating epithets follow them during play. The 12 custom Object Editor abilities inherit working Warcraft III spell templates and have additional scripted cast effects; they are not 12 wholly new spell engines.

## Invisible aura support

Each player (up to three) receives a **different invisible, invulnerable, Locust-enabled allied carrier** of type `hA01` at the map centre. Auras are placed exclusively on those carriers, not on playable heroes. Carrier appearance is made fully transparent instead of `ShowUnit(false)` so aura processing continues.

| Players | Carrier abilities | Additional global regeneration |
|---|---|---|
| 1 | A201 move/attack speed + A202 regen + A203 armor + A204 attack | +18 HP/s, +10 mana/s |
| 2 | A201 speed + A202 regen | +10 HP/s, +5 mana/s |
| 3 | A201 speed | +5 HP/s, +2.5 mana/s |
| 4 | None | None |

On player exit carriers are deleted and recreated for the remaining players, preventing stale bonuses. The aura area is set to 30,000 game units in `war3map.w3a`, sufficient to cover the arena.

## Four differentiated shops and twelve new items

Four unique shop units (`nS01` to `nS04`), each in its own location with an independent Object Editor name, model choice, and inventory:

| Shop | Unique stock |
|---|---|
| Shard Forge | Comet Blade, Frost Fang, Oathblade |
| Stone Guardian's Hold | Titan Bastion, Oath Helm, Silence Mantle |
| Crossroads Alchemist | First Dawn Elixir, Ether Condensate, Hourglass of Peace |
| Vault of Forbidden Relics | Heart of the Fallen Star, Clockmaker's Eye, Blood Moon Sigil |

Twelve custom items (`I001` through `I00C`) inherit reliable base-item effects, have custom names, descriptions and prices. Equipment also grants **scripted bonus hero stats on pickup** and removes them on drop. Some consumables also heal or restore mana to nearby allied heroes when used.

## Waves, loot and boss

10 waves, with a **75-second interval** instead of 60 seconds and fewer enemies than the previous build. Base wave population uses `(count * (humanPlayers + 2) + 5) / 8` rounded by integer division, minimum two per ring, and maximum **65** living wave enemies. The first wave remains 15 seconds after hero selection. Following wave 10 Kaz'Rul arrives after the interval.

Normal creeps have a low chance to drop unique items. Probability begins at **1.2%** in wave 1 and rises by 0.3 percentage points per wave; stronger enemy heroes add +2 percentage points and units of level 6+ add +1.5 percentage points. Early-wave drops favor consumables; mid-wave drops armor and weapons; late waves can drop rare relics. Gold is also earned via kills and wave completion.

Kaz'Rul scales its stats with player count, summons reinforcements and releases area magic at 65% and 30% HP; killing him wins.

## Build and validation

- `war3map.j`: runtime triggers, hero selection, custom spell effects, shop stock, aura carriers, loot/expedition pacing.
- `war3map.w3u`: custom unit data, names, stats, shops and carrier.
- `war3map.w3a`: custom ability data.
- `war3map.w3t`: custom item data.
- `object-data/hero_arena_objects.json`: readable source manifest of new objects.
- Existing terrain/pathing and map assets are unchanged.

Structural checks: JASS functions are balanced and native call names were compared to an older `common.j`/`blizzard.j` reference; custom binary Object Editor records were checked for structure and sizes. **These checks are not equivalent to compiling in the World Editor or testing gameplay in Warcraft III 1.26a.** If imports fail, verify archive paths and object-editor rawcodes. Test with 1–4 clients and check spell hotkeys, skill progression, shop purchasing, loot rarity, aura effect radius, and victory flow.

## Build a playable 1.26a .w3x (instead of manually creating a blank MPQ)

A Warcraft III map has a 512-byte `HM3W` header followed by an MPQ archive. A plain MPQ archive renamed to `.w3x` is not an adequate replacement.

**Windows / any computer with Python 3:** download the complete feature branch as a ZIP, extract it, open a terminal in the extracted repository root and run:

```powershell
py -3 tools/build_map.py --source . --output dist/Hero_Arena_126a.w3x
```

Place `dist/Hero_Arena_126a.w3x` in Warcraft III's Maps folder. It contains the script plus all `war3map.*` assets, including custom `.w3u`, `.w3t`, and `.w3a`. It converts Object Editor names and JASS text to Windows-1251 for the classic Russian client. It also checks for late JASS locals and missing required source files. **The builder's structural checks do not constitute a successful in-game launch test.**

A GitHub Actions workflow, `.github/workflows/build-map.yml`, can also build and upload the map artifact if Actions is enabled for the repository. Find it under Actions -> Build Warcraft III 1.26a map -> Run workflow (choose the feature branch) -> Artifacts -> Hero_Arena_126a. If no run appears, use the local Python command above.

The `object-data` JSON is documentation/source data for object generation. It is not an in-game archive component and should not be manually imported through MPQ Editor.

## October 10 hero progression and pacing update (Warcraft III 1.26a)

- **Hero learning menu:** use the **six custom hero IDs** (`H001`, `O001`, `H002`, `U001`, `E001`, `E002`). Their `uhab` lists now contain **four custom learnable skills each** (24 total; `A101`–`A10O`). Custom ability objects also contain level-specific research tooltips. Do **not** grant these abilities on spawn with `UnitAddAbility`: progression is entirely via the level-up interface.
- **Hero name labels:** the permanently following `texttag` was removed. Proper character names come from `war3map.w3u`.
- **Wave size:** the creature scaling multiplier was restored to the larger `(count * (activePlayers + 2) + 3) / 4`, with a cap of 85 existing wave enemies.
- **Wave pacing:** regular wave timeout is 95 seconds. If all wave enemies are killed, the next wave (or the boss after wave 10) is scheduled in **7 seconds** instead. Wave 1 still starts 15 seconds after everyone has chosen a hero.
- **Neutral enemies:** they are woken and removed from standard creep guard behavior on spawn, with an attack order towards the middle of the arena.
- **Permanent daylight:** the time is set to midday and suspended, so neutral creeps do not return to their normal night sleep cycle.
- **Four shops:** distinct custom unit types `nS01`–`nS04` with separate Object Editor `usei` inventories. The original `ngme` spawning/stock code is removed; invalid building-model overrides were removed from the custom data.

### Critical when testing using MPQ Editor

Replace at minimum **all three** files in the root of the map's MPQ archive: `war3map.j`, `war3map.w3u`, and `war3map.w3a`. Keep `war3map.w3t` to retain the custom items. If you replace **only** `war3map.j`, the custom heroes' proper names and learnable skill lists **will not appear** and the four store types might be missing. `object-data/hero_arena_objects.json` is source documentation and is not imported by the game.

These are source-level validations, not a successful test inside the Warcraft III 1.26a client. Retest in-game before treating the map as a stable release.
