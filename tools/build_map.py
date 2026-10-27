"""Build the Lua map from the unpacked sources, using only Python's stdlib.

MPQ v1 hash/block tables follow StormLib's format. Files use zlib-compressed
sectors without single-unit flags for Warcraft III map compatibility.
"""

from pathlib import Path
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Hero_Arena_126a.w3x"
MASK = 0xFFFFFFFF
SECTOR_SHIFT = 6
SECTOR_SIZE = 512 << SECTOR_SHIFT


def crypt_table():
    table = [0] * 0x500
    seed = 0x100001
    for i in range(256):
        for j in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            high = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[i + 256 * j] = high | (seed & 0xFFFF)
    return table


CRYPT = crypt_table()


def hash_name(name, kind):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for char in name.upper().encode("ascii"):
        seed1 = (CRYPT[kind * 256 + char] ^ (seed1 + seed2)) & MASK
        seed2 = (char + seed1 + seed2 + (seed2 << 5) + 3) & MASK
    return seed1


def encrypt_table(data, key):
    result = bytearray()
    seed = 0xEEEEEEEE
    for (value,) in struct.iter_unpack("<I", data):
        seed = (seed + CRYPT[0x400 + (key & 255)]) & MASK
        result.extend(struct.pack("<I", (value ^ (key + seed)) & MASK))
        key = (((~key << 21) + 0x11111111) | (key >> 11)) & MASK
        seed = (value + seed + (seed << 5) + 3) & MASK
    return bytes(result)


def pack_sectors(content):
    sectors = []
    for start in range(0, len(content), SECTOR_SIZE):
        raw = content[start:start + SECTOR_SIZE]
        compressed = b"\x02" + zlib.compress(raw, 9)
        sectors.append(compressed if len(compressed) < len(raw) else raw)
    offsets = [4 * (len(sectors) + 1)]
    for sector in sectors:
        offsets.append(offsets[-1] + len(sector))
    return struct.pack(f"<{len(offsets)}I", *offsets) + b"".join(sectors)


def script_language(info):
    """Read the language from the supported map-info v28 layout."""
    if struct.unpack_from("<I", info)[0] != 28:
        raise ValueError("war3map.w3i must use format 28 with Lua enabled")
    pos = 28  # version, save count, editor version, four game-version integers

    def skip_strings(count):
        nonlocal pos
        for _ in range(count):
            pos = info.index(0, pos) + 1

    skip_strings(4)
    pos += 8 * 4 + 4 * 4 + 3 * 4 + 1  # bounds, margins, size, flags, tileset
    pos += 4  # loading-screen background
    skip_strings(4)  # path, text, title, subtitle
    pos += 4  # game data set
    skip_strings(4)  # prologue path, text, title, subtitle
    pos += 24  # fog style, three floats, color, weather
    skip_strings(1)  # sound environment
    pos += 5  # light environment and water color
    return struct.unpack_from("<I", info, pos)[0]


def build():
    names = (ROOT / "(listfile)").read_text(encoding="ascii").splitlines()
    if len(names) != len(set(names)) or "war3map.lua" not in names:
        raise ValueError("The manifest must list each file once and include war3map.lua")
    if "war3map.j" in names or "(attributes)" in names:
        raise ValueError("Do not package the obsolete JASS script or stale MPQ attributes")
    if "(listfile)" not in names:
        raise ValueError("The manifest must include itself")
    if script_language((ROOT / "war3map.w3i").read_bytes()) != 1:
        raise ValueError("The map-info script language must be Lua (1)")
    files = []
    for name in names:
        path = (ROOT / name).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError(f"Invalid manifest entry: {name}")
        files.append((name, path.read_bytes()))

    count = 4
    while count < len(files) * 2:
        count *= 2
    hashes = [b"\xff" * 16] * count
    blocks = bytearray()
    payload = bytearray()
    for index, (name, content) in enumerate(files):
        offset = 32 + len(payload)
        packed = pack_sectors(content)
        blocks.extend(struct.pack("<4I", offset, len(packed), len(content), 0x80000200))
        payload.extend(packed)
        slot = hash_name(name, 0) % count
        while hashes[slot] != b"\xff" * 16:
            slot = (slot + 1) % count
        hashes[slot] = struct.pack("<IIHHI", hash_name(name, 1), hash_name(name, 2), 0, 0, index)

    hash_offset = 32 + len(payload)
    block_offset = hash_offset + 16 * count
    size = block_offset + len(blocks)
    header = struct.pack("<4sIIHH4I", b"MPQ\x1a", 32, size, 0, SECTOR_SHIFT,
                         hash_offset, block_offset, count, len(files))
    # Warcraft map preamble; MPQ begins at the next 512-byte boundary.
    preamble = (b"HM3W" + struct.pack("<I", 0) + b"Hero Arena\0"
                + struct.pack("<II", 0x120, 4)).ljust(512, b"\0")
    archive = (preamble + header + payload
               + encrypt_table(b"".join(hashes), hash_name("(hash table)", 3))
               + encrypt_table(blocks, hash_name("(block table)", 3)))
    temporary = OUTPUT.with_suffix(".w3x.tmp")
    temporary.write_bytes(archive)
    temporary.replace(OUTPUT)
    print(f"Built {OUTPUT.name}: {len(files)} files, {len(archive)} bytes (Lua, Warcraft III 1.31+)")


if __name__ == "__main__":
    build()
