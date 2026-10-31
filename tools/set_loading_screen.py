"""Encode the generated art as widescreen BLP1 with a stock fallback and set the native loading-screen lore.

Run with a Python environment containing Pillow. Ordinary map builds only copy
the already encoded assets and do not require Pillow.
"""
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets'/'loading'
MODEL_NAME='ArenaWide_v3.mdx'
TEXTURE_NAME='ArenaWide_v3.blp'


def loading_block(data):
    assert struct.unpack_from('<I',data)[0]==28
    pos=28
    for _ in range(4): pos=data.index(0,pos)+1
    pos+=32+16+12+1
    start=pos
    pos+=4
    for _ in range(4): pos=data.index(0,pos)+1
    return start,pos


def read_loading(data):
    start,end=loading_block(data)
    pos=start+4;strings=[]
    for _ in range(4):
        stop=data.index(0,pos);strings.append(data[pos:stop].decode('utf-8'));pos=stop+1
    return struct.unpack_from('<i',data,start)[0],strings


def encode_blp(image):
    from PIL import Image
    image=image.convert('RGB').resize((1920,1080),Image.Resampling.LANCZOS)
    indexed=image.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    palette=(indexed.getpalette()+[0]*768)[:768]
    bgra=b''.join(bytes((palette[i+2],palette[i+1],palette[i],0)) for i in range(0,768,3))
    mips=[]
    for level in range(11):
        size=(max(1,1920>>level),max(1,1080>>level))
        mip=image.resize(size,Image.Resampling.LANCZOS).quantize(palette=indexed,dither=Image.Dither.FLOYDSTEINBERG)
        mips.append(mip.tobytes())
    offsets=[];pos=1180
    for mip in mips: offsets.append(pos);pos+=len(mip)
    header=struct.pack('<4s6I',b'BLP1',1,0,1920,1080,5,0)
    header+=struct.pack('<16I',*(offsets+[0]*5))
    header+=struct.pack('<16I',*([len(m) for m in mips]+[0]*5))
    return header+bgra+b''.join(mips)


def apply(mode='wide-blp'):
    assert mode in ('wide-blp','standard')
    lore=json.loads((ASSETS/'lore.json').read_text(encoding='utf-8'))
    assert len(lore['text'])<550
    imports=[]
    if mode=='wide-blp':
        from PIL import Image
        (ROOT/TEXTURE_NAME).write_bytes(encode_blp(Image.open(ASSETS/'last-circle-wide.png')))
        model=bytearray((ASSETS/'LoadingScreen-wide-template.mdx').read_bytes())
        assert model.startswith(b'MDLX') and b'FullScreen.blp\0' in model
        position=model.index(b'FullScreen.blp\0')
        model[position:position+260]=(TEXTURE_NAME.encode()+b'\0').ljust(260,b'\0')
        (ROOT/MODEL_NAME).write_bytes(model)
        imports=[MODEL_NAME,TEXTURE_NAME]
    path=ROOT/'war3map.w3i';data=path.read_bytes();start,end=loading_block(data)
    strings=[MODEL_NAME if imports else '',lore['text'],lore['title'],lore['subtitle']]
    block=struct.pack('<i',-1 if imports else 0)+b''.join(text.encode('utf-8')+b'\0' for text in strings)
    path.write_bytes(data[:start]+block+data[end:])
    (ROOT/'war3map.imp').write_bytes(struct.pack('<2I',1,len(imports))+b''.join(b'\x0d'+name.encode()+b'\0' for name in imports))
    manifest=ROOT/'(listfile)'
    names=[name for name in manifest.read_text(encoding='ascii').splitlines()
           if name not in ('FullScreen.blp','FullScreen.dds','LoadingScreen.mdx','war3map.imp',MODEL_NAME,TEXTURE_NAME)]
    for name in imports+(['war3map.imp'] if imports else []): names.append(name)
    manifest.write_text('\n'.join(names)+'\n',encoding='ascii')
    print('Loading screen:',mode,'(DDS completely excluded from map)')


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--mode',choices=('wide-blp','standard'),default='wide-blp')
    apply(parser.parse_args().mode)
