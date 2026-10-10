# Hero Arena — pure Lua for Warcraft III: Reforged

## Download the compiled map

[**Download the GitHub Actions artifact**](https://github.com/olegsgames100/Warcraft-3-map-Ai/actions/runs/38066388850)

Under **Artifacts**, download `Hero_Arena_Lua_Reforged`; unzip it and take
`Hero_Arena_Lua_Reforged.w3x` from the ZIP.

This map's script is **Lua only**, not JASS.

## Map format

- Script entry: `war3map.lua`
- `war3map.w3i` uses map-info format 28, with `script_type = 1` for Lua
- JASS runtime `war3map.j` is omitted from the compiled MPQ
- The original map terrain, doodads, pathing, custom hero/shop/ability/item
  objects, map metadata and gameplay constants are included
- The `tools/build_pure_lua.py` script concatenates the four Lua modules and
  packages the resulting map (MPQ archive with Warcraft HM3W header)

## Included systems

- Ten actual custom hero unit definitions (not merely default heroes with
  different names), ten selectable professions in a northern 5x2 hall
- Forty custom Q/W/E/R hero abilities with five ranks, unique mana costs,
  cooldowns and Lua mechanics (traps, persistent zones, heals, dashes, summoning,
  execution, class resources and party ultimates)
- Deterministic STR/AGI/INT progression over twenty hero levels
- Fifty waves, ten themed sections changing every five waves, special
  minibosses, progressively better loot, four differentiated item shops
- Co-op support for one to four players, central stationary decorative
  guardian and passive regeneration scaling by team size
- Chat commands `-pick 1..10`, `-next`, `-kill`, `-revive`,
  `-maxlvl`, `-stats`
- No forced Warcraft III victory dialog after defeating the boss

## Lua sources

- `lua/map/00_core.lua` — configuration, gameplay helpers, map bootstrap
- `lua/map/10_heroes.lua` — hero choice, stats, progression, commands and shops
- `lua/map/20_abilities.lua` — 40 class skill handlers
- `lua/map/30_waves.lua` — waves, minibosses, loot and end boss
- `tools/build_pure_lua.py` — packs complete `.w3x` and validates MPQ content
- `.github/workflows/build-pure-lua.yml` — runs `luac5.4 -p`, assembles
  the archive and uploads a downloadable artifact

Manual build on Python 3:

```sh
python tools/build_pure_lua.py --source . --output dist/Hero_Arena_Lua_Reforged.w3x
```

## Verification and remaining risk

The GitHub Actions run **succeeded**: all Lua files passed the Lua parser,
the .w3x was built, its HM3W / MPQ signature and internal hash/block tables
were checked, and a download artifact was produced.

**Warcraft III Reforged has not been run here.** A Lua syntax check and
archive-integrity verification do **not** prove that the game will initialize,
load the custom objects or play all skills correctly. The version-28 metadata
is hand-generated from the map layout, so World Editor re-save or compatibility
fixes may still be necessary. Test with a backed-up map and send the exact
loading error or in-game result if it does not launch.

Also note: compared with the original JASS map, certain visual/UI systems
and complex hero mechanics have been reimplemented differently. This is the
first complete Lua runtime candidate, not an in-game-tested release.
