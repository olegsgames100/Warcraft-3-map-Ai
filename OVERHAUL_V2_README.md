# Hero Arena Lua — Overhaul V2 (Reforged)

This is an independent experimental overhaul branch. It does not change the previous `feature/reforged-pure-lua` branch.

## Major changes

- 40 Channel-based Q/W/E/R spells have been reserialized with float cooldown fields `acdn`, float `Ncl1`/`Ncl4` and fixed explicit icons, tooltips and ability card positions at every rank. Both the Object Editor and Lua enforce per-ability cooldowns; the intended Q/W/E/R ranges are ~7/14/17/52 seconds (with stronger R cooldowns for selected professions).
- Ten distinct hero-school visual profiles introduce cast flashes, impact effects, multi-point warning rings, ability zones, blast visuals and persistent effects with cleanup timers. Spell visuals use built-in Warcraft III models rather than requiring a third-party asset pack. **The chosen model paths need in-client checking.**
- Experience: `war3mapMisc.txt` disables inherited neutral-creep XP; the Lua wave death logic grants controlled amounts `floor(4 + wave*0.65 + (elite and 24 or 0))`. Level cap stays 20. Boss testing may require further tuning.
- Economy and item overhaul: 24 custom items have unique names, revised prices/descriptions and Lua interactions (multi-hit attack procs, lifesteal-like healing, ally support, rescue shields, spell procs, item-use AoE, cooldown recovery, charge-up mechanics). Their original Warcraft item parent properties still apply in addition to scripted passives. Item combination/build crafting is not yet implemented.
- World overhaul: batched terrain painting replaces the previously empty flat combat space with a central citadel floor, outer rune ring, different merchant courtyards, northern class-selection gallery, marked approach lanes and persistent decorative portals. Changes are done with Lua `SetTerrainType` during startup in small batches; original static terrain heights and cliffs have **not** been fully re-sculpted yet.
- Pure Lua runtime is retained: `war3map.lua` is compiled from six modules. No playable JASS script is imported into the map archive.

## How to get a build

Open [GitHub Actions — Compile Hero Arena Lua Overhaul V2](https://github.com/olegsgames100/Warcraft-3-map-Ai/actions/workflows/build-lua-overhaul.yml), select the latest successful build on branch `feature/reforged-lua-overhaul-v2`, and download artifact `Hero_Arena_Lua_Overhaul_V2`. Unzip it to get `Hero_Arena_Lua_Overhaul_V2.w3x`.

## Validation limits

CI compiles Lua syntax with `luac5.4 -p` and verifies the assembled HM3W/MPQ archive, but we cannot execute Warcraft III: Reforged itself here. Item triggers, ability visual model paths, hotkey usage, map terrain painting, multiplayer handling and combat balance are **not verified in-game**. This is a test candidate, not a confirmed stable release.

When testing, start with a fresh copy and validate: load to Wisp selection; pick one hero; cast Q/W/E/R; inspect each ability icon and cooldown; enter `-maxlvl` and try rank 5; buy and use one item from each merchant; defeat wave 5 miniboss; inspect new terrain and FPS. Send screenshots and the first broken mechanic for targeted fixes.
