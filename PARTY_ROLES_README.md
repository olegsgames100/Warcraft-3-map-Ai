# Hero Arena: Party Roles & Bone Brothers (12 Heroes / Pure Lua)

Based on `feature/reforged-lua-overhaul-v2`. This branch contains a complete first playable candidate of the **role-driven character redesign**, not a new JASS map.

## Team composition

| # | Character | Job | Damage school |
|---|---|---|---|
| 1 | Арбитр Рассвета | Main tank, taunt, protection, revive | Physical Q/E; magical R |
| 2 | Клинок Барханов | Melee physical DPS / combo | Physical |
| 3 | Проводник Гроз | Ranged mage / mana assistance | Magical |
| 4 | Владыка Пепла | Off-tank / necromancer / off-healing | Magical |
| 5 | Охотник Разлома | Mobile bruiser | Mixed |
| 6 | Лунная Провидица | **Dedicated healer** / shields / resurrect | Intelligence-based healing |
| 7 | Фенн Медный Котёл | **Dedicated buffer**: physical amp, spell amp, mana, shields | Support |
| 8 | Торвин Громовой Камень | Secondary tank / grouping and control | Physical |
| 9 | Лириса Сумеречная | Single-target physical finisher | Physical |
| 10 | Иссара Морозная | Ranged frost mage / roots | Magical |
| 11 | **Авалс, Костяной Снайпер** | Skeleton archer, ranged physical marksman | Physical |
| 12 | **Гело, Костяной Авангард** | Skeleton warrior, frontline protection and detonation | Physical |

Every hero has four unique Q/W/E/R skills, with five ranks unlocked at levels 1,5,9,13,17. Each skill has its own mana cost, cooldown, tooltip and icon in the generated Object Editor file, as well as a Lua handler.

## Mandatory stat rule

All **physical ability damage** is computed as `base * (1 + 0.015 * total_strength) * modifiers`.
All **magical ability damage** and **spell healing** use `base * (1 + 0.02 * total_intelligence) * modifiers`.
These are **skill** rules, not native basic attack formulas; Warcraft native attack mechanics still work. Strength means Strength even for an archer/assassin, as specifically requested.

## Two skeletons, one gameplay identity

**Авалс** uses a skeleton archer model, long-range physical attacks, bone marks and ranged volleys. **Гело** uses a skeleton warrior model, physical swings, taunts, shields and a charge.

* Авалс Q or W marks enemies with **Костяная метка** for nine seconds.
* Гело Q or E consumes those marks, deals an extra physical strike and leaves **Рассечение костей**, increasing physical skill damage taken for nine seconds. This makes follow-up arrows more lethal.
* Гело E empowers Авалс's next Q: **+75% physical base damage** for eight seconds.
* Авалс E gives Гело a shield and bonus physical damage.
* Гело W gives Авалс a special protective shield and resistance while taunting threats.
* Both R abilities used within a twelve-second window trigger **Смертельный союз**: combined physical area attacks, teamwide shields, and temporary physical damage buff.

All this is implemented in Lua; it is not merely tooltip text.

## Main developer files

- `object-data/party_heroes.json`: authoritative hero/spell name, role, stats, icon, cooldown and cost configuration.
- `tools/generate_party_objects.py`: rewrites existing Object Editor records and adds the two hero and eight new ability records at build time.
- `lua/map/10_heroes.lua`: selection, previews, stats, leveling, QWER IDs.
- `lua/map/15_combat.lua`: typed scaling, healing, shields, temporary buffs, slow/root, taunts and bone synergy.
- `lua/map/25_role_spells.lua`: 48 role-specific combat handlers.
- `tools/build_pure_lua.py`: assembles 8 Lua modules and packages the generated `.w3u` and `.w3a` binary files in a Lua-only MPQ-backed `.w3x` archive.
- `.github/workflows/build-party-roles.yml`: parser/object/build checks, map artifact.

## Build and test

```bash
python3 tools/generate_party_objects.py
luac5.4 -p lua/map/*.lua
python3 tools/build_pure_lua.py --source . --output dist/Hero_Arena_Party_Roles_12.w3x
```

`-pick 1` through `-pick 12` select characters; `-roles` lists the class selection; `-maxlvl` and `-stats` help check scaling.

## Limitations

The validated GitHub Actions run [#38070097828](https://github.com/olegsgames100/Warcraft-3-map-Ai/actions/runs/38070097828) **succeeded**: Lua syntax, all 12 object-based hero definitions, all 48 custom abilities and HM3W/MPQ packaging checks passed. Warcraft III Reforged runtime, hero creation, native Object Editor custom records, sound paths, visuals, combat balance and multiplayer performance **must still be tested inside the game**. This is an experimental overhaul branch, not an in-game-tested release. Existing map terrain, wave, item and shop systems are inherited from V2.

Recommended smoke test: select both skeletons in a two-player game; confirm their models and QWER hotkeys, rank 1–5 cooldowns, mark/consume/empowered arrow/paired ult. Then run tank+healer and mage+buffer groups through waves 1–10 before extended balancing.
