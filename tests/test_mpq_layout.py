import io
import random
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from build_map import pack_sectors,SECTOR_SIZE,SECTOR_SHIFT
from mpq_readback import W3XArchive


class SectorReadback(unittest.TestCase):
    def reader(self,content,flags=0x80000200):
        packed=pack_sectors(content)
        archive=W3XArchive.__new__(W3XArchive)
        archive.file=io.BytesIO(packed)
        archive.header={'offset':0,'sector_size_shift':SECTOR_SHIFT}
        archive.block_table=[SimpleNamespace(flags=flags,offset=0,archived_size=len(packed),size=len(content))]
        archive.get_hash_table_entry=lambda _:SimpleNamespace(block_table_index=0)
        return archive

    def test_raw_first_sector_followed_by_compressed_data(self):
        raw=random.Random(29).randbytes(SECTOR_SIZE)
        content=raw+b'A'*4000
        self.assertEqual(self.reader(content).read_file('fixture'),content)

    def test_exact_sector_boundary(self):
        content=b'A'*(SECTOR_SIZE*2)
        self.assertEqual(self.reader(content).read_file('fixture'),content)

    def test_reject_flag_not_allowed_in_w3x(self):
        with self.assertRaises(AssertionError):
            self.reader(b'fixture',0x81000200).read_file('fixture')


if __name__=='__main__':unittest.main()
