"""Apply built-in Warcraft appearances to the ten custom arena heroes.

Model paths and native scales checked against Units/unitUI.slk:
https://github.com/WarRaft/War3.mpq/blob/main/extract/Units/unitUI.slk
Native bases match their models so the engine resolves matching skins/animations.
Explicit combat modifications are preserved.
"""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
# Custom id, class name, built-in model, reference native scale, sound, RGB tint.
# Scale/model/animation fields are inherited from the native base, never overridden.
APPEARANCES = [
    ('H001', 'Тёмный Рыцарь', r'units\undead\HeroDeathKnight\HeroDeathKnight.mdl', 1.85, 'HeroDeathKnight', (220, 210, 230)),
    ('O001', 'Призрачный Ловчий', r'units\nightelf\herowarden\herowarden.mdl', 1.5, 'HeroWarden', (190, 210, 255)),
    ('H002', 'Элементалист Бури', r'units\human\HeroArchMage\HeroArchMage.mdl', 1.5, 'HeroArchMage', (190, 220, 255)),
    ('U001', 'Хранитель Древней', r'units\nightelf\HeroKeeperoftheGrove\HeroKeeperoftheGrove.mdl', 2.25, 'HeroKeeperoftheGrove', (255, 255, 255)),
    ('E001', 'Архилич Чумы', r'units\undead\HeroLich\HeroLich.mdl', 1.25, 'HeroLich', (190, 255, 190)),
    ('H003', 'Мастер Клинка-Ронин', r'units\orc\HeroBladeMaster\HeroBladeMaster.mdl', 1.25, 'HeroBladeMaster', (255, 255, 255)),
    ('E002', 'Жрица Рассвета', r'units\human\Jaina\Jaina.mdl', 1.5, 'Jaina', (255, 235, 200)),
    ('N001', 'Инженер-Бомбардир', r'Units\Creeps\HeroTinker\HeroTinker.mdl', 2.0, 'HeroTinker', (255, 255, 255)),
    ('E003', 'Железный Исполин', r'units\creeps\IronGolem\IronGolem.mdl', 1.75, 'IronGolem', (170, 180, 195)),
    ('U002', 'Хрономант', r'units\human\HeroBloodElf\HeroBloodElf.mdl', 1.5, 'BloodElfSorceror', (220, 210, 255)),
]
ICONS = ['BTNHeroDeathKnight', 'BTNHeroWarden', 'BTNHeroArchMage',
         'BTNKeeperOfTheGrove', 'BTNLichVersion2', 'BTNHeroBlademaster',
         'BTNJaina', 'BTNHeroTinker', 'BTNArmorGolem', 'BTNHeroBloodElfPrince']
BASES = ['Udea', 'Ewar', 'Hamg', 'Ekee', 'Ulic', 'Obla', 'Hjai', 'Ntin', 'Hmkg', 'Hblm']


def read_objects(data):
    """Read v1 unit modifications, retaining raw strings and numeric values."""
    version, = struct.unpack_from('<I', data)
    assert version == 1
    pos = 4
    tables = []
    for _ in range(2):
        count, = struct.unpack_from('<I', data, pos)
        pos += 4
        objects = []
        for _ in range(count):
            old, new, count = struct.unpack_from('<4s4sI', data, pos)
            pos += 12
            fields = []
            for _ in range(count):
                field, kind = struct.unpack_from('<4sI', data, pos)
                pos += 8
                end = data.index(0, pos) + 1 if kind == 3 else pos + 4
                value, marker = data[pos:end], data[end:end + 4]
                pos = end + 4
                fields.append((field, kind, value, marker))
            objects.append((old, new, fields))
        tables.append(objects)
    assert pos == len(data)
    return tables


def write_objects(tables):
    result = bytearray(struct.pack('<I', 1))
    for objects in tables:
        result.extend(struct.pack('<I', len(objects)))
        for old, new, fields in objects:
            result.extend(struct.pack('<4s4sI', old, new, len(fields)))
            for field, kind, value, marker in fields:
                result.extend(struct.pack('<4sI', field, kind) + value + marker)
    return bytes(result)


def apply():
    path = ROOT / 'war3map.w3u'
    tables = read_objects(path.read_bytes())
    objects = {new.decode('ascii'): fields for _, new, fields in tables[1]}
    native_bases = {entry[0]: base.encode('ascii') for entry, base in zip(APPEARANCES, BASES)}
    tables[1] = [(native_bases.get(new.decode('ascii'), old), new, fields)
                 for old, new, fields in tables[1]]
    for (rawcode, name, model, scale, sound, tint), icon in zip(APPEARANCES, ICONS):
        fields = objects[rawcode]
        changes = {}
        for field, value in [('usnd', sound), ('unam', name), ('utip', name), ('upro', name), ('uhab', '')]:
            changes[field.encode()] = (3, value.encode('utf-8') + b'\0')
        if rawcode == 'E003':
            changes[b'umdl'] = (3, model.encode('ascii') + b'\0')
        changes[b'uico'] = (3, ('ReplaceableTextures\\CommandButtons\\' + icon + '.blp').encode('ascii') + b'\0')
        for field, value in zip([b'uclr', b'uclg', b'uclb'], tint):
            changes[field] = (0, struct.pack('<i', value))
        # usca is a REAL (type 1); the previous type-2 override was invalid.
        # Remove that override entirely and inherit the native scale/model/tags.
        fields[:] = [entry for entry in fields if entry[0] not in changes
                     and entry[0] not in (b'umdl', b'usca', b'uani')]
        fields.extend((field, kind, value, b'\0' * 4) for field, (kind, value) in changes.items())
    path.write_bytes(write_objects(tables))
    print('Applied appearances to 10 custom heroes')


if __name__ == '__main__':
    apply()
