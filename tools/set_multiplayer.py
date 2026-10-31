"""Enable the four human slots as a fixed cooperative team in W3I v28.

Flag definitions: War3Net.Build.Info MapFlags.cs / ForceFlags.cs.
"""
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]


def layout(data):
    assert struct.unpack_from('<I',data)[0]==28
    pos=28
    for _ in range(4): pos=data.index(0,pos)+1
    flags=pos+32+16+8
    pos+=32+16+12+1+4
    for _ in range(4): pos=data.index(0,pos)+1
    pos+=4
    for _ in range(4): pos=data.index(0,pos)+1
    pos+=24
    pos=data.index(0,pos)+1
    pos+=5+4
    count,=struct.unpack_from('<I',data,pos);pos+=4
    players=[]
    for _ in range(count):
        players.append(struct.unpack_from('<4I',data,pos));pos+=16
        pos=data.index(0,pos)+1+16
    forces,=struct.unpack_from('<I',data,pos);pos+=4
    assert count==4 and forces==1
    assert [p[0] for p in players]==list(range(4))
    assert all(p[1]==1 for p in players), 'all slots must accept human users'
    return flags,pos


def apply():
    path=ROOT/'war3map.w3i';data=bytearray(path.read_bytes())
    flags,force=layout(data)
    current,=struct.unpack_from('<I',data,flags)
    struct.pack_into('<I',data,flags,current | 0x60)
    # Allied + allied victory + shared vision; heroes remain independently controlled.
    struct.pack_into('<2I',data,force,0x0b,0x0f)
    path.write_bytes(data)
    print('Enabled 1-4 player co-op lobby: fixed allies and shared vision')


if __name__=='__main__': apply()
