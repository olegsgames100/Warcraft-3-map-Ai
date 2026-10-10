# Reforged Lua rewrite — work branch

This branch is **not a playable Lua map yet**. It inherits the Reforged JASS map and
introduces a native Lua gameplay module as the first step towards a proper rewrite.

## What has already been fixed in the playable Reforged/JASS map

- The ten heroes now receive explicit STR, AGI, INT growth through level 20.
- Growth is based on their own class data, applied on `EVENT_PLAYER_HERO_LEVEL`
  and checked on the periodic tick. `-maxlvl` also triggers a recalculation.
- Object Editor stat growth for all ten custom heroes is set to 0 to prevent double scaling.
- The `-stats` command displays the current base attributes.
- Changes are in `war3map.j` and `war3map.w3u`.

## Lua plan

Warcraft III Reforged supports Lua as a map scripting language, but **a live JASS
`war3map.j` map cannot simply `require` Lua code**. The World Editor must
save/convert the map with Lua selected, producing a `war3map.lua` entry and
the corresponding map script-language metadata.

Initial module: `lua/arena/hero_growth.lua`.

Migration phases:
1. Convert a copy of the map in Reforged World Editor to Lua scripting mode.
   Verify successful loading and player slots/terrain before adding gameplay.
2. Replace startup/hero selection in native Lua. Integrate and test the
   deterministic `hero_growth.lua` module. When the Lua module owns stat
   growth, disable/remove the JASS growth system entirely; do not run both.
3. Move custom Channel skill casting, cooldowns and actual mechanics into
   separate hero ability modules (one hero at a time).
4. Rebuild 50-wave director, five-wave themes, difficulty budgets and elite AI.
5. Rebuild item affixes, four specialist merchants, drop tiers and crafting.
6. Move guardian aura carriers, HUD, combat text and victory/postgame handling.
7. Enable multiplayer synchronization and test 1–4 players, reconnect/leave,
   hero leveling, death/revival and boss phases.

## Important integration detail

`lua/arena/hero_growth.lua` is a **source module**, not automatically imported
into the `.w3x`. In a Lua-enabled map you may inline the code, or bundle it
into a compatible Lua loader before `war3map.lua` executes. The current
`tools/build_reforged.py` only packs `war3map.j`, not a Lua map runtime.

No playable Lua build, Lua compiler validation, or Reforged client gameplay test
has been completed for this branch. Test existing JASS stat fixes first via the
Reforged branch, then begin the Lua conversion with a separate map archive.
