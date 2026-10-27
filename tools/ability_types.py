"""Numeric types from Blizzard AbilityMetaData.slk (WarRaft/War3.mpq).

https://github.com/WarRaft/War3.mpq/blob/main/extract/Units/AbilityMetaData.slk

Real and unreal are distinct engine types even though both encode float32.
"""
import json
from pathlib import Path
import struct

TYPES = json.loads(Path(__file__).with_name('ability_numeric_types.json').read_text())
assert len(TYPES) > 100 and TYPES.get('aran') == 2, 'Missing/invalid AbilityMetaData type table'


def normalize(fields, types=TYPES):
    result = []
    for field,kind,level,pointer,value,marker in fields:
        expected = types.get(field.decode('ascii'))
        if expected is not None and kind != expected:
            assert kind in (0,1,2), f'Non-numeric data for {field!r}'
            number = struct.unpack('<i' if kind == 0 else '<f',value)[0]
            kind = expected
            value = struct.pack('<i',int(number)) if kind == 0 else struct.pack('<f',float(number))
        result.append((field,kind,level,pointer,value,marker))
    return result
