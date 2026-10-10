# Hero Arena — Kaz'Rul's Last Stand

Cooperative **Warcraft III (classic 1.26a) JASS** arena for **1–4 human players**. The source files in this repository are *unpacked map contents*, not a playable `.w3x` by themselves. Import these files into an existing map archive / use a Warcraft III map editor; keep binary assets and Object Editor data intact.

## Core game loop

1. A Wisp spawns for each human at the northern selection hall. Move it onto any of six hero statues (the selection region accepts the Wisp), or type `-pick 1` ... `-pick 6`. An automatic random choice occurs after 90 seconds.
2. Each hero receives a starter inventory and abilities on top of their standard Warcraft III hero toolkit.
3. Four neutral shops stand around the centre (weapons, armour, consumables, relics).
4. First wave arrives **15 seconds after everyone chooses**, followed by **one wave every 60 seconds**.
5. There are ten progressively stronger enemy compositions, followed **60 seconds after wave 10** by the final boss **Kaz'Rul**.
6. Defeat Kaz'Rul for victory. Dead heroes revive after 12 seconds.

## Physical map layout

- A **stone fighting circle** with a central paved dais and decorative perimeter trees.
- A separate **northern selection plaza** with six stone hero platforms (3 x 2), hero previews, floating name labels and walk-in trigger regions.
- A paved north-to-centre walkway.
- All layout terrain and decorations are created dynamically from `war3map.j`, using `SetTerrainType` and destructable placement. The existing `war3map.w3e` binary remains untouched.
- Start initialization occurs after 0.5 seconds of game time to allow the client interface to come up before selection. The selection timer is 90 seconds.

## Heroes

| Choice | Warcraft III base hero | Theme |
|---|---|---|
| Arbiter of the Arena | Paladin | Support / frontline tank |
| Dustblade | Blademaster | Mobile melee damage |
| Stormkeeper | Archmage | Spellcasting / crowd control |
| Ash Lord | Death Knight | Undead bruiser |
| Void Hunter | Demon Hunter | Agile skirmisher |
| Moon Sentinel | Priestess of the Moon | Ranged support |

Signature add-on abilities use stock Warcraft III ability rawcodes defined in `Arena_GiveSkills`; hero-native spell progression remains available through normal level-ups. These are predefined *loadouts*, not fully custom Object Editor abilities.

## Adaptive co-op difficulty

| Human players | Enemy wave count multiplier (approx.) | Global hero bonuses |
|---|---:|---|
| 1 | 0.75× | 6 extra aura/passive abilities; +18 HP/+10 mana per second; increased handicap/XP |
| 2 | 1.00× | 3 extra abilities; +10 HP/+5 mana per second; increased handicap/XP |
| 3 | 1.25× | 1 extra ability; +5 HP/+2.5 mana per second; modest handicap/XP |
| 4 | 1.50× | **No solo/team catch-up buffs** |

The actual spawn amount is rounded up and capped at 130 living wave enemies to limit runaway accumulation. If a player leaves, surviving players' catch-up buffs are refreshed and the opening hero-selection gate can advance.

## Boss — Kaz'Rul

Kaz'Rul grows with the number of active humans (level and hero stats), has an undead aura loadout, and enters two phases:

- **65% HP:** summons skeleton reinforcements and releases a short-range magic nova.
- **30% HP:** summons infernals, gains a roar ability and uses a stronger magic nova.

Boss reinforcements use the same adaptive wave multiplier. The boss is identified separately from wave creeps for victory tracking.

## Progression and shops

Players start with 450 gold, a circlet and healing/mana potions. Each wave gives **40 + 15 × wave number** gold to all active humans. The killer of an ordinary wave enemy earns another **4 + 2 × current wave** gold. Shops stock existing Warcraft III items, with fixed in-game stock levels.

## Technical notes / testing

- Main gameplay script: `war3map.j`, JASS for Warcraft III 1.26a.
- Source branch: `govno`; feature branch: `feature/hero-arena-expanded`.
- Basic structural checks can validate function boundaries and game-event wiring; **actual gameplay and object rawcode availability must be verified in Warcraft III**.
- Recommended test matrix: 1, 2, 3, 4 connected players; buying items; deaths and revives; one player leaving before hero pick; all 10 waves; both boss phases; boss death victory; pathing/spawn locations.
- Map terrain bounds and shop placements are inherited from the source map. Adjust wave spawn radius or arena geometry in `war3map.j` if terrain blocks enemy pathing.
