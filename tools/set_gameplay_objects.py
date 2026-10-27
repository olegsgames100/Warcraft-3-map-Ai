"""Build the self-only Torment status and the blue Sky Barge summon."""
from pathlib import Path
import struct
import json
from set_hero_models import read_objects, write_objects
from set_ability_ui import read
from ability_types import normalize

ROOT = Path(__file__).resolve().parents[1]


def value(v):
    if isinstance(v, str): return 3, v.encode('utf-8') + b'\0'
    if isinstance(v, float): return 1, struct.pack('<f', v)
    return 0, struct.pack('<i', v)


def apply():
    path = ROOT / 'war3map.w3a'
    tables = read(path.read_bytes())
    fields = []
    def ability(field, v, level=0, pointer=0):
        kind, data = value(v)
        fields.append((field.encode(), kind, level, pointer, data, b'\0'*4))
    for field, v in [('anam','Щит Мучений — статус'), ('aher',0), ('alev',1),
                     ('aart',r'ReplaceableTextures\CommandButtons\BTNDivineIntervention.blp'),
                     ('abpx',0), ('abpy',-11)]:
        ability(field, v)
    for field, v in [('aare',1.0), ('atar','self'), ('abuf','BS01'),
                     ('adur',0.0), ('ahdu',0.0)]:
        ability(field, v, 1)
    ability('Had1',0.0,1,1)  # UI marker only; numeric armor is handled by Lua.
    ability('Had2',0,1,2)
    tables[1] = [entry for entry in tables[1] if entry[1] != b'AS01']
    tables[1].append((b'AHad',b'AS01',fields))
    corona_fields = [(f,k,l,p,v,m) for f,k,l,p,v,m in fields if f not in (b'Had1',b'Had2',b'abuf',b'anam')]
    corona_fields.extend([
        (b'anam',3,0,0,'Очищающий Ореол — статус'.encode()+b'\0',b'\0'*4),
        (b'abuf',3,1,0,b'BC01\0',b'\0'*4),
        (b'Ear1',2,1,1,struct.pack('<f',0.0),b'\0'*4)
    ])
    tables[1] = [entry for entry in tables[1] if entry[1] != b'AC01']
    tables[1].append((b'AEar',b'AC01',corona_fields))
    result = bytearray(struct.pack('<I',1))
    for objects in tables:
        result.extend(struct.pack('<I',len(objects)))
        for old,new,fields in objects:
            result.extend(struct.pack('<4s4sI',old,new,len(fields)))
            for field,kind,level,pointer,data,marker in normalize(fields):
                result.extend(struct.pack('<4s3I',field,kind,level,pointer)+data+marker)
    path.write_bytes(result)

    def fields_of(changes):
        return [(field.encode(),*value(v),b'\0'*4) for field,v in changes]
    # Buffs use the same unlevelled object layout as units.
    buff = ROOT / 'war3map.w3h'
    tables = read_objects(buff.read_bytes()) if buff.exists() else [[],[]]
    tables[1] = [entry for entry in tables[1] if entry[1] != b'BS01']
    tables[1].append((b'BHad',b'BS01',fields_of([
        ('fnam','Щит Мучений'), ('ftip','Щит Мучений'),
        ('fube','Увеличены максимальное здоровье и броня. На первом уровне: +210 здоровья и +15 брони. Длительность: 8 секунд.'),
        ('fart',r'ReplaceableTextures\CommandButtons\BTNDivineIntervention.blp')
    ])))
    tables[1] = [entry for entry in tables[1] if entry[1] != b'BC01']
    tables[1].append((b'BEar',b'BC01',fields_of([
        ('fnam','Очищающий Ореол'),('ftip','Очищающий Ореол'),
        ('fube','Скорость передвижения увеличена на 35% на 5 секунд. После окончания ореол оглушит ближайших врагов на 1,2 секунды.'),
        ('fart',r'ReplaceableTextures\CommandButtons\BTNDivineIntervention.blp')
    ])))
    buff.write_bytes(write_objects(tables))

    units = ROOT / 'war3map.w3u'
    tables = read_objects(units.read_bytes())
    # Native creep flee behavior also runs when attacking the engineer's towers.
    import re
    source = (ROOT / 'war3map.lua').read_text(encoding='utf-8')
    wave_source = source[source.index('function Arena_EliteType('):source.index('function Arena_BossNova(')]
    creep_ids = {raw.encode() for raw in re.findall(r"FourCC\('([^']{4})'\)",wave_source)
                 if raw.startswith(('n','u')) or raw=='Nplh'}
    originals = {old:fields for old,_,fields in tables[0]}
    for raw in sorted(creep_ids):
        if raw not in originals:
            fields=[];tables[0].append((raw,b'\0'*4,fields))
        else:
            fields=originals[raw]
        fields[:] = [entry for entry in fields if entry[0] != b'ufle']
        fields.extend(fields_of([('ufle',0)]))
    tables[1] = [entry for entry in tables[1] if entry[1] != b'uL01']
    tables[1].append((b'uarb',b'uL01',fields_of([
        ('unam','Ледяной Конструкт'), ('utip','Ледяной Конструкт'),
        ('uico',r'ReplaceableTextures\CommandButtons\BTNUndeadAirBarge.blp'),
        ('uabi',''), ('umvt','fly'), ('umvh',150.0), ('umvs',300),
        ('uclr',80), ('uclg',140), ('uclb',255)
    ])))
    for raw,name,scale in [('eD01','Железнокорый Древень',1.5),('eD02','Первобытный Колосс',2.5)]:
        tables[1] = [entry for entry in tables[1] if entry[1] != raw.encode()]
        tables[1].append((b'efon',raw.encode(),fields_of([
            ('unam',name),('utip',name),('uabi',''),('usca',scale),('umvs',280)
        ])))
    for base,raw,changes in [
        (b'hfoo',b'eC01',[('unam','Хроно-Эхо'),('utip','Хроно-Эхо'),('uabi',''),('uaen',0),('umvs',0),
                         ('umdl',r'units\human\HeroBloodElf\HeroBloodElf.mdl'),('usca',1.5),
                         ('uclr',100),('uclg',170),('uclb',255)]),
        (b'efon',b'eD03',[('unam','Молодой Древень'),('utip','Молодой Древень'),('uabi',''),('usca',0.8),('umvs',300)]),
        (b'hctw',b'hT01',[('unam','Орудийная Турель'),('utip','Орудийная Турель'),('uabi',''),
                         ('uhpm',650),('uaen',0),('ufoo',0)])
    ]:
        tables[1] = [entry for entry in tables[1] if entry[1] != raw]
        tables[1].append((base,raw,fields_of(changes)))
    unit_types = json.loads((ROOT / 'tools' / 'unit_numeric_types.json').read_text())
    assert unit_types.get('umvh') == 2 and unit_types.get('usca') == 1
    for objects in tables:
        for _,_,fields in objects:
            normalized = normalize([(f,k,0,0,v,m) for f,k,v,m in fields], unit_types)
            fields[:] = [(f,k,v,m) for f,k,_,_,v,m in normalized]
    units.write_bytes(write_objects(tables))
    print('Built Torment status/buff and blue flying Sky Barge')


if __name__ == '__main__':
    apply()
