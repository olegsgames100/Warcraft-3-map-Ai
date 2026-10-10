# Hero Arena — Warcraft III: Reforged edition

**Separate development branch:** `feature/reforged-custom-hero-arena`.
Base: `fix/custom-heroes-startup-isolation`; the Warcraft III 1.26a branches remain unchanged.

## Contents

- A 50-wave co-op arena for 1–4 human players, with 10 themes changing every 5 waves, named mini-bosses and a boss after wave 50.
- **10 actual custom Object Editor heroes**: `H001`, `O001`, `H002`, `U001`, `E001`, `E002`, `N001`, `H003`, `E003`, `U002`. Their names, descriptions, stats, models inherited from ten different Reforged-supported Warcraft heroes, and abilities are defined in `war3map.w3u`. These are not just renamed stock hero selections.
- **40 custom Object Editor Channel spells**, four Q/W/E/R actions for each hero, with five ranks, separate mana costs, cooldowns, tooltips and icons. These are defined in `war3map.w3a` and implemented in JASS in `war3map.j`.
- A collection of 24 custom objects/items in `war3map.w3t`, 4 independent shop units, stat-based solo/duo scaling, chat commands and a no-victory-dialog post-boss state.
- `war3mapMisc.txt` provides max hero level 20 and XP scaling.

## Hero classes and intended skills

| Hero | Q | W | E | R |
|---|---|---|---|---|
| Паладин-защитник | Клеймо света | Купол клятвы | Перехват | Последний рассвет |
| Мастер клинка | Песчаный рывок | Рваные клинки | Миражи барханов | Буря тысячи лезвий |
| Боевой архимаг | Цепной разряд | Грозовой столб | Магический контур | Штормовой катаклизм |
| Рыцарь смерти | Печать погибели | Костяной дозор | Жатва эссенции | Чёрный легион |
| Охотник на демонов | Разрез реальности | Выжечь разум | Фел-ловушка | Владыка бездны |
| Лунная жрица | Серебряная стрела | Священная роща | Плащ затмения | Падение созвездий |
| Алхимик-боевик | Гремучий флакон | Кислотная воронка | Жадная трансмутация | Философский эликсир |
| Горный король | Раскол земной коры | Магнитный кулак | Гранитная твердыня | Гнев исполина |
| Сумрачная охотница | Шаг за грань | Клеймо охотницы | Дымовая завеса | Приговор ночи |
| Ледяной лич | Копьё вечного льда | Ледяные цепи | Орбита холода | Вечная зима |

The 40 spells have separate ability definitions and triggers. Several currently share *implementation primitives* (instant area damage/healing, temporary summons, short dashes, conditional executions), so delayed traps, persistent resource systems and unique status effects are **not yet completely developed**. Their descriptions in `object-data/ten_hero_skill_design.json` also include design goals beyond the currently implemented effects.

## Obtain a .w3x

**GitHub Actions:** Open Actions -> **Reforged Hero Arena map build**. Choose **Run workflow**, select `feature/reforged-custom-hero-arena`, wait for the run, and download the `Hero_Arena_Reforged` artifact.

**Local Python 3:** from the checked-out branch root:

```bash
python tools/build_reforged.py --source . --output dist/Hero_Arena_Reforged.w3x
```

The output is an MPQ-backed `.w3x` containing the map script, terrain, units, abilities, items and gameplay constants. It uses UTF-8 for text rather than converting to the Windows-1251 text of the older 1.26a map.

**Alternative:** use Warcraft III Reforged's World Editor to open and inspect the map; if the manually built archive is rejected, inspect the script and Object Editor data in the editor and save using the editor's own map format.

## Important validation limits

- The map's binary unit and ability data were parsed and round-tripped; all ten hero IDs have their corresponding four ability IDs; each of those 40 abilities has five Channel ranks and configured Q/W/E/R keys.
- JASS static checks: 97 definitions matched 97 endfunction statements, no late local declarations, and no unknown calls versus a classic Warcraft III JASS common/blizzard reference.
- **Warcraft III Reforged was not available to compile or run this map here.** The custom skill orders, in-game QWER behavior, MPQ acceptance and all gameplay mechanics remain **unverified in the client**. Treat this as a buildable development candidate, not a tested release.
- Make a backup of any existing map. Do not combine `war3map.w3u` and `war3map.w3a` from incompatible branches.
