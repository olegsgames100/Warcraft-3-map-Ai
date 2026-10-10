# Ten fully redesigned Hero Arena classes — experimental Warcraft III 1.26a branch

This branch is a **new experimental skill-system overhaul** based on `feature/hero-arena-expanded`. It leaves the last relatively stable branch untouched.

## What changes

All ten professions use **stock playable hero types** (`Hpal`, `Obla`, `Hamg`, `Udea`, `Edem`, `Emoo`, `Nalc`, `Hmkg`, `Ewar`, `Ulic`) because custom hero unit imports previously caused native crashes at hero selection. The original profession now has **four custom Channel-based spell buttons** with unique cooldowns and mana costs (Q/W/E/R) rather than vanilla abilities with a cosmetic rider.

Spells automatically advance through five ranks at hero levels **1, 5, 9, 13 and 17**. Classic hero skill points are removed from the game loop so players do not have to level up the old skill tree. Spell effects are implemented in `war3map.j` instead of inheriting damage from vanilla abilities.

## The redesigned kits

| Profession | Q | W | E | R |
|---|---|---|---|---|
| Паладин-защитник | Клеймо света (judgement) | Купол клятвы (healing/guard zone) | Перехват (dash) | Последний рассвет (resurrect/heal) |
| Мастер клинка | Песчаный рывок | Рваные клинки (multi-hit) | Миражи барханов (summon) | Буря тысячи лезвий |
| Боевой архимаг | Цепной разряд (AoE energy) | Грозовой столб (repeated arcs) | Магический контур (mana) | Штормовой катаклизм |
| Рыцарь смерти | Печать погибели (execute) | Костяной дозор | Жатва эссенции (drain) | Чёрный легион |
| Охотник на демонов | Разрез реальности (dash) | Выжечь разум | Фел-ловушка | Владыка бездны |
| Лунная жрица | Серебряная стрела | Священная роща | Плащ затмения | Падение созвездий |
| Алхимик-боевик | Гремучий флакон | Кислотная воронка | Жадная трансмутация | Философский эликсир |
| Горный король | Раскол земной коры | Магнитный кулак | Гранитная твердыня | Гнев исполина |
| Сумрачная охотница | Шаг за грань | Клеймо охотницы | Дымовая завеса | Приговор ночи |
| Ледяной лич | Копьё вечного льда | Ледяные цепи | Орбита холода | Вечная зима |

**Implementation caveat:** Not every concept is feature-complete. Current mechanics are scripted direct effects (distinct combinations of area attacks, targeted low-life finishers, teleports, hero healing, mana restoration, timed summon squads and multi-strike bursts). Persistent ground areas, delayed traps, persistent marks, crowd-control durations, collision-safe blinks, and per-class resources are **design intentions, not yet implemented faithfully**. The full specification is at `object-data/ten_hero_skill_design.json`.

## Data and installation

- `war3map.j` — QWER attachment, auto-ranking and scripted spell effects.
- `war3map.w3a` — forty custom Channel abilities, five ranks each, QWER buttons with four different base orders.
- `object-data/ten_hero_skill_design.json` — detailed design/role descriptions.
- All other map files come from the previous feature branch.

**MPQ Editor:** back up your working map first and replace `war3map.j` and `war3map.w3a` at the MPQ root. Maintain the current `war3map.w3u`, `war3map.w3t` and `war3mapMisc.txt`. If the game crashes or abilities fail to appear, restore your backup.

**Validation:** JASS static structure (98 balanced functions), late-local ordering and native function calls were checked against 1.26a-style `common.j`/`blizzard.j`. The binary ability records were round-trip parsed. This **does not prove in-game function**. Critically, Channel object fields, order IDs, ability flags and actual casting/hotkey behavior still need testing in the Warcraft III 1.26a client. Do not treat this branch as a completed, stable gameplay release.
