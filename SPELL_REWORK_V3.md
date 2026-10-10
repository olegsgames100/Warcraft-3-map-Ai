# Hero Arena — Rebuild V3: Individual Spells and Native Targeting

This is a replacement of the old layered generic spell system, not a fourth override of the same handler.

## Runtime architecture

`tools/build_pure_lua.py` includes **only**:

- `lua/map/21_spell_meta.lua`: 48 ability identifiers, costs, cooldowns, intended target modes.
- `lua/map/22_spell_events.lua`: exactly one SPELL_CAST / SPELL_EFFECT dispatcher, target snapshot, error diagnostics and deduplication.
- `lua/map/27_rebuilt_spells.lua`: 48 explicit ability handlers, one Q/W/E/R for each of 12 characters.
- `lua/map/15_combat.lua` and `lua/map/16_role_mechanics.lua`: combat primitives, typed Strength/Intelligence damage scaling, taunts, protective links, shields, burns, stuns, mines, bleeds and dual skeleton ultimates.

Legacy files `20_abilities.lua`, `25_role_spells.lua` and `26_unique_kits.lua` remain visible for history but **are not assembled into the map**. No code in the archived map overrides these 48 handlers.

## Reforged object targeting fixes

`object-data/party_heroes.json` explicitly declares a target mode (`unit`, `point`, `instant`) for every skill.

`tools/generate_party_objects.py` now writes *Channel* (`Ncl1`) as **integer** 0=instant, 1=unit, 2=point for all 5 ranks, as well as dedicated base orders (`Ncl6`). It writes targeting range and native costs/cooldowns.

Normal attacks: original 10 heroes preserve their own inherited weapon missiles and weapon kinds. Two skeletons receive their own attack field settings. The attack cooldown (`ua1c`) varies per character from 1.7 to 2.5 seconds. There is no forced generic arrow for every ranged hero.

## Role kit design

| Hero | Q | W | E | R |
|---|---|---|---|---|
| Reynar — Tank | Cone taunt | Placed shield bastion | Rescue ally | Stored-Resolve dawn |
| Zarhan — Melee DPS | Bleeding dash | Triple wound | Timed parry | Precision execution |
| Mirella — Ranged Mage | Unit-target chain lightning | Placed conductor | Mana tether to ally | Two-site overload |
| Morven — Necro Offtank | Cursed target | Skeleton guards | Life-to-ally transfer | Soul-powered undead push |
| Valtir — Bruiser | Rift-scar charge | Unit-target magic burn | Proximity mine network | Form / mine detonation |
| Selena — Healer | Emergency unit heal | Placed healing grove | Targeted protective link | Team resurrection |
| Fenn — Buffer | Target stimulant | Corrosive flask | Ally catalyst | Team-wide alchemy |
| Torvin — Control Tank | Target hammer stun | Point gravity pull | Reactive stone stance | Knockback quake |
| Lyrisa — Assassin | Target backstab | Death mark | Return to saved shadow | Mark-consuming execute |
| Issara — Control Mage | Traveling ice projectile | Unit-root frost chains | Oriented ice wall | Frost-stack shatter |
| Avals — Ranged Skeleton | Long shot / bone mark | Seven-shot target volley | Sniper stance / Gelo shield | Unit-target boneyard snipe |
| Gelo — Melee Skeleton | Mark-detonating slash | Ally damage interception | Point charge / Avals bonus | Skeleton wall / paired ultimate |

All 48 skills use bespoke implementation rather than being aliases for `area`, `dash`, or `zone` alone. Shared primitives support different gameplay loops.

## Validation and known limitations

GitHub Actions checks Lua syntax, invokes **all 48 spell handlers** in a mocked Warcraft Lua environment, parses the generated Object Editor files, verifies **48 target modes**, **240 mana costs** and inventory abilities, and assembles the MPQ-backed `.w3x`.

**In-game Reforged validation is still needed.** In particular: actual Channel target selection / spell order collisions, graphics, native projectile inheritance and hero attack cadence cannot be conclusively verified by the mocked runtime.

Enable `-debugspells` to report CAST/EFFECT/FALLBACK or a Lua exception during a live test. Test target selection for Q/W/E across Paladin, Blademaster, Priestess, mage and skeletons, along with ordinary attack cadence.
