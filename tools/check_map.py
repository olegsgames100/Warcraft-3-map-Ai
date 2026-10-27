"""Independent MPQ readback and Lua 5.3 startup smoke checks.

Install optional check dependencies with: python -m pip install lupa mpyq
"""

import io
from pathlib import Path
import struct

import mpyq
from lupa.lua53 import LuaRuntime
from build_map import script_language
from set_hero_models import read_objects, BASES, APPEARANCES
from set_ability_ui import read as read_abilities
from ability_types import TYPES


ROOT = Path(__file__).resolve().parents[1]


def check():
    data = (ROOT / "Hero_Arena_126a.w3x").read_bytes()
    assert data[:4] == b"HM3W"
    archive = mpyq.MPQArchive(io.BytesIO(data[512:]))
    names = (ROOT / "(listfile)").read_text(encoding="ascii").splitlines()
    assert set(archive.files) == {name.encode("ascii") for name in names}
    assert archive.read_file("war3map.j") is None
    for name in names:
        assert archive.read_file(name) == (ROOT / name).read_bytes(), name
    assert script_language(archive.read_file("war3map.w3i")) == 1
    source = archive.read_file("war3map.lua").decode("utf-8")
    units = {int.from_bytes(new, 'big'): (old, {f: value for f, _, value, _ in fields})
             for old, new, fields in read_objects(archive.read_file('war3map.w3u'))[1]}
    abilities = {int.from_bytes(new, 'big'): {(f, level): value for f, _, level, _, value, _ in fields}
                 for _, new, fields in read_abilities(archive.read_file('war3map.w3a'))[1]}
    for entry, base in zip(APPEARANCES, BASES):
        old, fields = units[int.from_bytes(entry[0].encode(), 'big')]
        assert old == base.encode()
        if entry[0] == 'E003':
            assert fields[b'umdl'] == b'units\\creeps\\IronGolem\\IronGolem.mdl\0'
        else:
            assert b'umdl' not in fields
        assert fields[b'uhab'] == b'\0'
        assert b'usca' not in fields and b'uani' not in fields, 'inherit native scale and animation tags'
    harness = (ROOT / "tests" / "startup_smoke.lua").read_text(encoding="utf-8")
    for active_players in (1, 4):
        for role in range(1, 11):
            lua = LuaRuntime()
            lua.execute(harness)
            lua.execute(source)
            lua.globals().RunStartupSmoke(role, active_players)
            hero = lua.globals().HeroClasses[role]
            assert hero.id in units
            for slot in range(1, 5):
                fields = abilities[hero.spells[slot]]
                assert fields[b'aher', 0] == struct.pack('<I', 0)
                assert fields[b'ahky', 0] == b'QWER'[slot-1:slot]+b'\0'
                assert fields[b'aart', 0].endswith(b'.blp\0')
                assert len(fields[b'aub1', 1].decode('utf-8')) > 40
                for level in range(1, 6):
                    tooltip = fields[b'aub1', level].decode('utf-8')
                    assert 'Доступна сразу' not in tooltip and 'Обучение через' not in tooltip
                    assert '(' not in fields[b'atp1', level].decode('utf-8'), 'client adds the hotkey'
                    assert f'Ранг {level}/5' in fields[b'atp1',level].decode('utf-8')
    print(f"OK: {len(names)} archived files match sources; Lua 5.3 compiles")
    print("OK: 20 startup scenarios (1/4 players, 10 heroes, dialog/chat), first wave, crafting")
    print("OK: invalid/repeated choices and failed hero creation")
    print("OK: 10 native hero bases, 40 spell buttons and learning disabled on spawn/level")
    lua = LuaRuntime()
    lua.execute(harness)
    lua.execute(source)
    original_induction = lua.globals().Arena_ApplyInductionStack
    lua.execute((ROOT / 'tests' / 'ability_smoke.lua').read_text(encoding='utf-8'))
    assert len(TYPES)>100 and TYPES['aran']==2
    for raw in (b'A105', b'A106', b'A109'):
        fields = abilities[int.from_bytes(raw,'big')]
        assert struct.unpack('<f',fields[b'aran',1])[0] == 1200
    buff_objects = read_objects(archive.read_file('war3map.w3h'))[1]
    assert any(new==b'BS01' for _,new,_ in buff_objects)
    assert units[int.from_bytes(b'uL01','big')][0] == b'uarb'
    height = next((kind,value) for old,new,fields in read_objects(archive.read_file('war3map.w3u'))[1]
                  if new==b'uL01' for field,kind,value,_ in fields if field==b'umvh')
    assert height == (2,struct.pack('<f',150.0))
    assert units[int.from_bytes(b'eD03','big')][0] == b'efon'
    assert units[int.from_bytes(b'hT01','big')][0] == b'hctw'
    for _,_,fields in read_abilities(archive.read_file('war3map.w3a'))[1]:
        for field,kind,_,_,_,_ in fields:
            expected = TYPES.get(field.decode())
            if expected is not None: assert kind == expected, field
    for raw in (b'eD01',b'eD02'):
        assert units[int.from_bytes(raw,'big')][0] == b'efon'
    lua.execute((ROOT / 'tests' / 'direction_parry_smoke.lua').read_text(encoding='utf-8'))
    lua.globals().Arena_ApplyInductionStack = original_induction
    lua.execute((ROOT / 'tests' / 'rework_smoke.lua').read_text(encoding='utf-8'))
    lua.execute((ROOT / 'tests' / 'combat_feedback_smoke.lua').read_text(encoding='utf-8'))
    lua.execute((ROOT / 'tests' / 'chrono_wave_smoke.lua').read_text(encoding='utf-8'))
    print('OK: Echo 16s cooldown, acceleration preserves cooldowns, late/exit/overlapping chronospheres, 45s waves/7s after clear, ranked formulas/AoE cursors')
    for raw in (b'A115',b'A116',b'A117',b'A118'):
        assert struct.unpack('<f',abilities[int.from_bytes(raw,'big')][b'acdn',1])[0]>0
    assert any(new==b'BC01' for _,new,_ in buff_objects)
    from ability_numbers import TARGET_AREAS
    for raw,radius in TARGET_AREAS.items():
        fields=abilities[int.from_bytes(raw.encode(),'big')]
        for level in range(1,6):
            assert struct.unpack('<i',fields[b'Ncl3',level])[0] & 2
            assert struct.unpack('<f',fields[b'aare',level])[0]==radius
    echo_fields=abilities[int.from_bytes(b'A11F','big')]
    assert struct.unpack('<f',echo_fields[b'acdn',1])[0]==16
    print('OK: no creep guard/retreat, attacks/casts uninterrupted, dash-only reset, corona refresh/status, 40 timed visuals')
    print('OK: readable stack counters, persistent conductivity FX, flying constructor/slow/cold damage, distant living skeletons, turret damage/cap')
    shadow = next(entry for entry in read_abilities(archive.read_file('war3map.w3a'))[1] if entry[1]==b'A104')
    assert shadow[0]==b'AOwk' and all(not f.startswith(b'Ncl') for f,_,_,_,_,_ in shadow[2])
    print('OK: aim at origin/unit, line collision/nearest hit, parry without invulnerability, druid summons, native Wind Walk')
    print('OK: shield stats/refresh/expiry, 1-second field ticks, corpse damage/healing, cast ranges and summon/buff objects')
    print("The smoke check simulates Warcraft natives; an in-game launch still needs verification.")


if __name__ == "__main__":
    check()
