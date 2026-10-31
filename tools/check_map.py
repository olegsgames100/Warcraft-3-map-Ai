"""Independent MPQ readback and Lua 5.3 startup smoke checks.

Install optional check dependencies with: python -m pip install lupa mpyq
"""

import io
from pathlib import Path
import struct

import mpyq
from mpq_readback import W3XArchive
from lupa.lua53 import LuaRuntime
from build_map import script_language
from set_hero_models import read_objects, BASES, APPEARANCES
from set_ability_ui import read as read_abilities
from ability_types import TYPES


ROOT = Path(__file__).resolve().parents[1]


def check():
    data = (ROOT / "Hero_Arena_126a.w3x").read_bytes()
    assert data[:4] == b"HM3W"
    archive = W3XArchive(io.BytesIO(data[512:]))
    names = (ROOT / "(listfile)").read_text(encoding="ascii").splitlines()
    assert set(archive.files) == {name.encode("ascii") for name in names}
    assert archive.read_file("war3map.j") is None
    for name in names:
        assert archive.read_file(name) == (ROOT / name).read_bytes(), name
    assert script_language(archive.read_file("war3map.w3i")) == 1
    from set_loading_screen import read_loading,MODEL_NAME,TEXTURE_NAME
    background,loading=read_loading(archive.read_file('war3map.w3i'))
    assert loading[3]=='ПОСЛЕДНИЙ КРУГ' and 'Каз\'Рул' in loading[1]
    assert archive.read_file('FullScreen.dds') is None, 'unsupported DDS must not return'
    if loading[0]:
        assert background==-1 and loading[0]==MODEL_NAME
        model=archive.read_file(loading[0])
        assert model[:4]==b'MDLX' and TEXTURE_NAME.encode()+b'\0' in model
        assert b'FullScreen.dds' not in model
        pos=4
        while pos<len(model):
            chunk_length,=struct.unpack_from('<I',model,pos+4);pos+=8+chunk_length
        assert pos==len(model)
        texture=archive.read_file(TEXTURE_NAME)
        assert texture[:4]==b'BLP1'
        assert struct.unpack_from('<6I',texture,4)==(1,0,1920,1080,5,0)
        end=1180
        for level in range(11):
            offset,=struct.unpack_from('<I',texture,28+4*level)
            length,=struct.unpack_from('<I',texture,92+4*level)
            assert offset==end and length==max(1,1920>>level)*max(1,1080>>level)
            end=offset+length
        assert end==len(texture)
        assert TEXTURE_NAME.encode()+b'\0' in archive.read_file('war3map.imp')
        print('OK: native BLP1 1920x1080, complete mip chain, no DDS references')
    else:
        assert background==0
        assert archive.read_file(MODEL_NAME) is None
        assert archive.read_file(TEXTURE_NAME) is None
        assert archive.read_file('war3map.imp') is None
        print('OK: stock loading preset, no custom model/texture/imports; lore preserved')
    assert max(map(len,loading[1].splitlines()))<=25
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
    for active_players in (1, 2, 4):
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
    print("OK: 30 startup scenarios (1/2/4 players, 10 heroes, dialog/chat), first wave, crafting")
    from set_multiplayer import layout
    info=archive.read_file('war3map.w3i')
    flags,force=layout(info)
    assert struct.unpack_from('<I',info,flags)[0]&0x60==0x60
    assert struct.unpack_from('<2I',info,force)==(0x0b,0x0f)
    for leave in (False,True):
        coop=LuaRuntime();coop.execute(harness);coop.execute(source)
        coop.globals().RunCoopSmoke(leave)
    print('OK: co-op lobby flags, reciprocal allies/vision, two independent choices/spawns, readiness, equal wave gold, leave-before-choice recovery')
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
    for rank in range(1,6): assert struct.unpack('<f',abilities[int.from_bytes(b'A115','big')][b'acdn',rank])[0]==8
    assert any(new==b'BC01' for _,new,_ in buff_objects)
    from ability_numbers import TARGET_AREAS
    for raw,radius in TARGET_AREAS.items():
        fields=abilities[int.from_bytes(raw.encode(),'big')]
        for level in range(1,6):
            assert struct.unpack('<i',fields[b'Ncl3',level])[0] & 2
            assert struct.unpack('<f',fields[b'aare',level])[0]==radius
    echo_fields=abilities[int.from_bytes(b'A11F','big')]
    assert struct.unpack('<f',echo_fields[b'acdn',1])[0]==16
    for rank in range(1,6):
        assert struct.unpack('<i',abilities[int.from_bytes(b'A10H','big')][b'amcs',rank])[0]==200
        assert struct.unpack('<f',abilities[int.from_bytes(b'A10H','big')][b'acdn',rank])[0]==30
        assert struct.unpack('<i',abilities[int.from_bytes(b'A10I','big')][b'amcs',rank])[0]==250
        assert struct.unpack('<i',abilities[int.from_bytes(b'A10L','big')][b'Ncl2',rank])[0]==2
    keeper=units[int.from_bytes(b'U001','big')][1]
    assert keeper[b'upra']==b'STR\0'
    for rank in range(1,6):
        for raw,cost,cd in [('A10B',45+10*rank,7),('A10C',50+10*rank,12),('A10N',75+10*rank,20),('A10O',180+25*rank,65)]:
            f=abilities[int.from_bytes(raw.encode(),'big')]
            assert struct.unpack('<i',f[b'amcs',rank])[0]==cost
            assert struct.unpack('<f',f[b'acdn',rank])[0]==cd
        w=abilities[int.from_bytes(b'A116','big')]
        e=abilities[int.from_bytes(b'A117','big')]
        assert struct.unpack('<i',w[b'Ncl2',rank])[0]==2
        assert w[b'aart',0]!=e[b'aart',0]
        assert w[b'Ncl6',rank]!=e[b'Ncl6',rank]
        assert struct.unpack('<f',e[b'Ncl1',rank])[0]>rank+1
    import configparser
    misc=configparser.ConfigParser(comment_prefixes=('//',';','#'))
    misc.read_string(archive.read_file('war3mapMisc.txt').decode())
    assert misc.getint('Misc','MaxHeroLevel')==30
    assert list(map(int,misc['Misc']['HeroFactorXP'].split(',')))==[100]*30
    assert misc.getint('Misc','BuildingKillsGiveExp')==1
    from set_landscape import ground, ground_height, decorations
    terrain=archive.read_file('war3map.w3e')
    assert terrain[:9]==b'W3E!\x0b\0\0\0L'
    pos=13
    count,=struct.unpack_from('<I',terrain,pos);pos+=4+count*4
    count,=struct.unpack_from('<I',terrain,pos);pos+=4+count*4
    width,height,ox,oy=struct.unpack_from('<2I2f',terrain,pos);pos+=16
    assert len(terrain)==pos+width*height*7
    for row in range(height):
        for col in range(width):
            x,y=ox+col*128,oy+row*128
            offset=pos+(row*width+col)*7
            assert terrain[offset+4]&15==ground(x,y)
            assert struct.unpack_from('<H',terrain,offset)[0]==8192+round(ground_height(x,y)*4)
    trees,props=decorations()
    assert len(trees)==72 and len(props)==32
    assert all(x*x+y*y>1900**2 and min(abs(x),abs(y))>450 for x,y,*_ in trees)
    minimap=archive.read_file('war3mapMap.blp')
    assert minimap[:4]==b'BLP1' and struct.unpack_from('<5I',minimap,4)==(1,0,256,256,5)
    for i in range(9):
        offset,=struct.unpack_from('<I',minimap,28+i*4)
        length,=struct.unpack_from('<I',minimap,92+i*4)
        assert length==(256>>i)**2 and offset+length<=len(minimap)
        assert max(minimap[offset:offset+length])<6
    fresh=LuaRuntime();fresh.execute(harness);fresh.execute(source)
    fresh.execute((ROOT/'tests'/'balance_landscape_smoke.lua').read_text(encoding='utf-8'))
    economy=LuaRuntime();economy.execute(harness);economy.execute(source)
    economy.execute((ROOT/'tests'/'economy_smoke.lua').read_text(encoding='utf-8'))
    from set_items import GEAR, RELICS, CONSUMABLES
    item_tables=read_objects(archive.read_file('war3map.w3t'))
    item_data={old if new==b'\0'*4 else new:{f:v for f,_,v,_ in fields}
               for table in item_tables for old,new,fields in table}
    for raw,price,_,_ in CONSUMABLES:
        f=item_data[raw.encode()]
        assert struct.unpack('<i',f[b'igol'])[0]==price>=400
        assert struct.unpack('<i',f[b'iuse'])[0]==1
        assert struct.unpack('<i',f[b'istr'])[0]==60
    for raw,_,_,_,_,_,_ in GEAR: assert item_data[raw.encode()][b'iabi']==b'\0'
    for raw,_,_ in RELICS: assert item_data[raw.encode()][b'ipaw']==b'\0'*4
    print('OK: two shops, 400+ gold consumables/limited stock, 9 recipes, real gear stats/removal, no free HP/mana refill, block/spell damage')
    print('OK: W3E terrain heights/textures, clear combat floor/entrances, 104 border decorations and BLP1 mip chain')
    print('OK: level-5 ultimate lock/unlock, all-target moving fire chains, one scaling guardian, hit-based overcharge chain lightning, storm without healing, corpse caps 5/7/9/11/13 and 1% mana; automatic ranks, split Q, passive bleed and reflect stance')
    print('OK: no creep guard/retreat, attacks/casts uninterrupted, dash cooldown enforced at 8s, corona refresh/status, 40 timed visuals')
    print('OK: readable stack counters, persistent conductivity FX, flying constructor/slow/cold damage, distant living skeletons, turret damage/cap')
    shadow = next(entry for entry in read_abilities(archive.read_file('war3map.w3a'))[1] if entry[1]==b'A104')
    assert shadow[0]==b'AOwk' and all(not f.startswith(b'Ncl') for f,_,_,_,_,_ in shadow[2])
    print('OK: aim at origin/unit, line collision/nearest hit, Q dash, delayed Iai W, 2-6s reflect stance, druid summons, native Wind Walk')
    print('OK: shield stats/refresh/expiry, 1.5-second field ticks, corpse damage/healing, cast ranges and summon/buff objects')
    print("The smoke check simulates Warcraft natives; an in-game launch still needs verification.")


if __name__ == "__main__":
    check()
