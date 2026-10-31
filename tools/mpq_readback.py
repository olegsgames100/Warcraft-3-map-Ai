"""Strict W3X sector readback using mpyq's independent header/hash parser.

mpyq 0.2.5 guesses compression by comparing a sector length with the remaining
FILE size. Thus a full raw sector followed by another sector is mistaken for
compressed data. Compare with that sector's expected size instead. Also use
ceil division: mpyq miscounts sectors when file size is an exact multiple.
"""
import struct
import zlib
import mpyq


class W3XArchive(mpyq.MPQArchive):
    def read_file(self,filename,force_decompress=False):
        entry=self.get_hash_table_entry(filename)
        if entry is None: return None
        block=self.block_table[entry.block_table_index]
        assert block.flags==0x80000200, f'Non-W3X resource flags: {filename!r}: {block.flags:#x}'
        self.file.seek(self.header['offset']+block.offset)
        data=self.file.read(block.archived_size)
        sector_size=512<<self.header['sector_size_shift']
        count=(block.size+sector_size-1)//sector_size
        offsets=struct.unpack_from(f'<{count+1}I',data)
        assert offsets[0]==4*(count+1) and offsets[-1]==len(data)
        parts=[]
        for i in range(count):
            assert offsets[i]<=offsets[i+1]
            payload=data[offsets[i]:offsets[i+1]]
            expected=min(sector_size,block.size-i*sector_size)
            if len(payload)<expected:
                assert payload[0]==2, 'only zlib sectors are emitted by this builder'
                payload=zlib.decompress(payload[1:])
            assert len(payload)==expected
            parts.append(payload)
        return b''.join(parts)
