"""Author a quiet meadow arena; keep the combat floor and four entrances open.

W3E v11: preserve water, boundary, cliff and pathing data; only change ground
texture/detail and gently raise the outer banks. Decorative trees stay outside
the 1,900-unit combat circle. Deterministic output, no third-party dependencies.
"""
from pathlib import Path
import math
import random
import struct

ROOT = Path(__file__).resolve().parents[1]
COLORS = [(111,98,65), (102,94,69), (111,111,71), (109,112,101), (94,112,66), (73,94,57)]


def noise(x,y,scale):
    x,y=x/scale,y/scale
    ix,iy=math.floor(x),math.floor(y)
    fx,fy=x-ix,y-iy
    fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
    def sample(a,b):
        n=(a*374761393+b*668265263+4128)&0xffffffff
        n=((n^(n>>13))*1274126177)&0xffffffff
        return (n^(n>>16))/0xffffffff
    low=sample(ix,iy)*(1-fx)+sample(ix+1,iy)*fx
    high=sample(ix,iy+1)*(1-fx)+sample(ix+1,iy+1)*fx
    return low*(1-fy)+high*fy


def ground(x, y):
    radius = math.hypot(x, y)
    # Broad patches avoid a noisy tile-by-tile checkerboard.
    patch = noise(x,y,1450)*0.75+noise(x,y,650)*0.25
    road = min(abs(x - 65*math.sin(y/620)), abs(y - 65*math.sin(x/620)))
    if radius < 240:
        return 3
    if road < 115 and radius < 3400:
        return 0
    if road < 205 and radius < 3400:
        return 2
    if 1660 < radius < 1810 and abs(x)>370 and abs(y)>370:
        return 2
    if radius < 1650:
        return 2 if patch > 0.68 else 4
    return 5 if patch > 0.61 else 4


def ground_height(x, y):
    bank = max(0,min(1,(math.hypot(x,y)-1900)/650))
    return bank * (24+18*math.sin(x/750)*math.cos(y/810))


def decorations():
    rng = random.Random(4128)
    trees, props = [], []
    for cluster in range(8):
        angle = math.radians(24 + cluster*45)
        for i in range(9):
            a = angle + rng.uniform(-0.11, 0.11)
            r = rng.uniform(2250, 2950)
            x, y = math.cos(a)*r, math.sin(a)*r
            if min(abs(x), abs(y)) < 450:
                continue
            trees.append((x,y,rng.uniform(0,360),rng.uniform(0.85,1.2),rng.randrange(10)))
        for i in range(4):
            a = angle + rng.uniform(-0.12,0.12)
            r = rng.uniform(2000,2200)
            path = ('Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks%d.mdl' % rng.randrange(6)
                    if i < 2 else 'Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub%d.mdl' % rng.randrange(3))
            props.append((path, math.cos(a)*r, math.sin(a)*r, rng.uniform(0,6.28), rng.uniform(0.7,1.05)))
    return trees,props


def apply():
    path = ROOT/'war3map.w3e'
    data = bytearray(path.read_bytes())
    assert data[:9] == b'W3E!\x0b\0\0\0L'
    pos = 13
    count, = struct.unpack_from('<I',data,pos);pos += 4
    assert [bytes(data[pos+i*4:pos+i*4+4]) for i in range(count)] == [b'Ldrt',b'Ldro',b'Ldrg',b'Lrok',b'Lgrs',b'Lgrd']
    pos += count*4
    count, = struct.unpack_from('<I',data,pos);pos += 4+count*4
    width,height,ox,oy = struct.unpack_from('<2I2f',data,pos);pos += 16
    assert len(data)==pos+width*height*7
    for row in range(height):
        for col in range(width):
            x,y = ox+col*128, oy+row*128
            offset = pos+(row*width+col)*7
            tile = ground(x,y)
            data[offset+4] = (data[offset+4]&0xf0)|tile
            data[offset+5] = 0  # Use quiet native texture variants, no bones/cracks.
            elevation = ground_height(x,y)
            struct.pack_into('<H',data,offset,8192+round(elevation*4))
    path.write_bytes(data)
    trees,props = decorations()
    lines = ['-- BEGIN GENERATED LANDSCAPE', 'function Arena_CreateLandscape()']
    for x,y,angle,scale,variation in trees:
        # Use the native destructable so its replaceable summer texture is set.
        lines += [f"    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), {x:.2f}, {y:.2f}, {angle:.2f}, {scale:.3f}, {variation}), true)"]
    lines += ['    local effect']
    for model,x,y,angle,scale in props:
        lines += [f'    effect = AddSpecialEffect("{model}", {x:.2f}, {y:.2f})',
                  f'    BlzSetSpecialEffectYaw(effect, {angle:.3f})',
                  f'    BlzSetSpecialEffectScale(effect, {scale:.3f})']
    lines += ['end', '-- END GENERATED LANDSCAPE']
    source = (ROOT/'war3map.lua').read_text(encoding='utf-8')
    if '-- BEGIN GENERATED LANDSCAPE' in source:
        a=source.index('-- BEGIN GENERATED LANDSCAPE')
        b=source.index('-- END GENERATED LANDSCAPE',a)+len('-- END GENERATED LANDSCAPE')
        source=source[:a]+source[b:]
    (ROOT/'war3map.lua').write_text(source.rstrip()+'\n\n'+'\n'.join(lines)+'\n',encoding='utf-8')

    # Matching paletted BLP1 minimap, complete mip chain for the engine.
    def pixels(size):
        result=bytearray()
        for y in range(size):
            for x in range(size):
                wx,wy = ox+(x+0.5)/size*(width-1)*128, oy+(size-y-0.5)/size*(height-1)*128
                result.append(ground(wx,wy))
        return result
    palette = b''.join(struct.pack('<4B',b,g,r,0) for r,g,b in COLORS)+b'\0'*4*(256-len(COLORS))
    sizes=[256>>i for i in range(9)]
    mips=[pixels(size) for size in sizes]
    offsets=[];offset=156+1024
    for mip in mips: offsets.append(offset);offset+=len(mip)
    header=struct.pack('<4s6I',b'BLP1',1,0,256,256,5,0)
    header+=struct.pack('<16I',*(offsets+[0]*7))+struct.pack('<16I',*([len(m) for m in mips]+[0]*7))
    (ROOT/'war3mapMap.blp').write_bytes(header+palette+b''.join(mips))
    print(f'Built quiet meadow terrain, {len(trees)} border trees, {len(props)} rocks/shrubs, matching minimap')


if __name__ == '__main__':
    apply()
