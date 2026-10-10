#!/usr/bin/env python3
"""Build an HM3W + MPQ Warcraft III Reforged map from unpacked war3map.* files.

MPQ v0, single-unit blocks without compression, no third-party dependencies.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import struct

FILES = (
    "war3map.j", "war3map.w3i", "war3map.w3e", "war3map.wpm",
    "war3map.shd", "war3map.doo", "war3mapUnits.doo", "war3map.wtg",
    "war3map.wct", "war3map.wts", "war3map.w3c", "war3map.w3r",
    "war3map.mmp", "war3mapMap.blp", "war3map.w3u", "war3map.w3a",
    "war3map.w3t", "war3mapMisc.txt",
)
REQUIRED = {"war3map.j", "war3map.w3i", "war3map.w3e", "war3map.wpm"}
MASK = 0xFFFFFFFF


def make_crypt_table():
    table = [0] * 1280
    seed = 0x00100001
    for a in range(256):
        for b in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            n = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[b * 256 + a] = n | (seed & 0xFFFF)
    return table


CRYPT = make_crypt_table()


def hash_name(name, typ):
    a, b = 0x7FED7FED, 0xEEEEEEEE
    for ch in name.replace("/", "\\").upper().encode("ascii"):
        a = (CRYPT[typ * 256 + ch] ^ (a + b)) & MASK
        b = (ch + a + b + (b << 5) + 3) & MASK
    return a


def cipher(data, key, decrypt=False):
    a, b = key, 0xEEEEEEEE
    out = bytearray()
    for i in range(0, len(data), 4):
        b = (b + CRYPT[1024 + (a & 255)]) & MASK
        encoded = struct.unpack_from("<I", data, i)[0]
        plain = encoded ^ ((a + b) & MASK)
        out += struct.pack("<I", plain)
        a = (((~a & MASK) << 21) + 0x11111111 | (a >> 11)) & MASK
        b = ((plain if decrypt else encoded) + b + (b << 5) + 3) & MASK
    return bytes(out)


def convert_object_strings(data, is_ability):
    """Object strings are kept as UTF-8 for the Reforged build."""
    at = 0
    out = bytearray()

    def take(n):
        nonlocal at
        if at + n > len(data):
            raise ValueError("Truncated Object Editor file")
        out.extend(data[at:at + n])
        at += n

    def number():
        nonlocal at
        if at + 4 > len(data):
            raise ValueError("Truncated Object Editor integer")
        x = struct.unpack_from("<I", data, at)[0]
        at += 4
        return x

    def put(x):
        out.extend(struct.pack("<I", x))

    version = number()
    put(version)
    if version not in (1, 2):
        raise ValueError("Unsupported object-data version")
    for _ in range(2):
        count = number()
        put(count)
        if count > 20000:
            raise ValueError("Invalid object count")
        for _ in range(count):
            take(8)  # base ID, new ID
            modifications = number()
            put(modifications)
            if modifications > 10000:
                raise ValueError("Invalid modification count")
            for _ in range(modifications):
                take(4)  # field ID
                typ = number()
                put(typ)
                if is_ability:
                    take(8)  # level and data pointer
                if typ == 3:
                    end = data.find(b"\0", at)
                    if end < 0:
                        raise ValueError("Unterminated object string")
                    raw = data[at:end]
                    at = end + 1
                    try:
                        raw = raw.decode("utf-8").encode("cp1251")
                    except (UnicodeDecodeError, UnicodeEncodeError):
                        pass
                    out.extend(raw)
                    out.append(0)
                elif typ in (0, 1, 2):
                    take(4)
                else:
                    raise ValueError("Unknown modification type")
                take(4)  # trailing original ID
    if at != len(data):
        raise ValueError("Extra bytes in object file")
    return bytes(out)


def check_jass(src):
    text = src.decode("utf-8")
    if len(re.findall(r"^function\s+", text, re.M)) != len(re.findall(r"^endfunction$", text, re.M)):
        raise ValueError("JASS functions do not balance")
    for m in re.finditer(r"^function\s+(\w+)\s+takes[^\n]*\n(.*?)^endfunction", text, re.M | re.S):
        seen = False
        for line in m.group(2).splitlines():
            line = line.strip()
            if not line or line.startswith("//"):
                continue
            if line.startswith("local "):
                if seen:
                    raise ValueError("Late local declaration in " + m.group(1))
            else:
                seen = True


def build(root, destination):
    files = {}
    for name in FILES:
        file = root / name
        if not file.is_file():
            if name in REQUIRED:
                raise FileNotFoundError(file)
            continue
        content = file.read_bytes()
        if name == "war3map.j":
            check_jass(content)
            content = content
        elif name in ("war3map.w3u", "war3map.w3a", "war3map.w3t"):
            content = content
        files[name] = content
    files["(listfile)"] = ("\r\n".join((*files, "(listfile)")) + "\r\n").encode("ascii")
    entries = list(files.items())
    hashes = 1 << max(4, (len(entries) * 2 - 1).bit_length())
    offset = 32
    blocks = []
    for name, content in entries:
        blocks.append((offset, len(content), len(content), 0x81000000))
        offset = (offset + len(content) + 3) & ~3
    hash_offset = offset
    block_offset = hash_offset + hashes * 16
    archive_size = block_offset + len(blocks) * 16
    mpq = bytearray(archive_size)
    struct.pack_into("<4sIIHHIIII", mpq, 0, b"MPQ\x1a", 32, archive_size, 0, 3,
                     hash_offset, block_offset, hashes, len(blocks))
    for (name, content), (pos, _, _, _) in zip(entries, blocks):
        mpq[pos:pos + len(content)] = content
    raw_hash = bytearray(b"\xff" * (hashes * 16))
    for idx, (name, _) in enumerate(entries):
        slot = hash_name(name, 0) & (hashes - 1)
        while struct.unpack_from("<I", raw_hash, slot * 16 + 12)[0] != MASK:
            slot = (slot + 1) & (hashes - 1)
        struct.pack_into("<IIII", raw_hash, slot * 16, hash_name(name, 1), hash_name(name, 2), 0, idx)
    raw_block = b"".join(struct.pack("<IIII", *b) for b in blocks)
    mpq[hash_offset:block_offset] = cipher(raw_hash, hash_name("(hash table)", 3))
    mpq[block_offset:] = cipher(raw_block, hash_name("(block table)", 3))
    header = bytearray(512)
    header[:8] = b"HM3W\0\0\0\0"
    name = b"Hero Arena Reforged\0"
    header[8:8 + len(name)] = name
    struct.pack_into("<II", header, 8 + len(name), 0x120, 4)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(header + mpq)
    # Confirm tables decrypt, filename hashes resolve and contents match.
    actual = destination.read_bytes()
    if actual[:4] != b"HM3W" or actual[512:516] != b"MPQ\x1a":
        raise AssertionError("Bad Warcraft map signature")
    hash_loc, block_loc, hash_count, block_count = struct.unpack_from("<IIII", actual, 528)
    h = cipher(actual[512 + hash_loc:512 + hash_loc + hash_count * 16],
               hash_name("(hash table)", 3), decrypt=True)
    b = cipher(actual[512 + block_loc:512 + block_loc + block_count * 16],
               hash_name("(block table)", 3), decrypt=True)
    for name, content in entries:
        slot = hash_name(name, 0) & (hash_count - 1)
        for _ in range(hash_count):
            x, y, _, idx = struct.unpack_from("<IIII", h, slot * 16)
            if x == hash_name(name, 1) and y == hash_name(name, 2):
                begin, packed, raw, flags = struct.unpack_from("<IIII", b, idx * 16)
                if packed != raw or raw != len(content) or flags != 0x81000000:
                    raise AssertionError("Bad MPQ block: " + name)
                if actual[512 + begin:512 + begin + len(content)] != content:
                    raise AssertionError("Corrupted MPQ entry: " + name)
                break
            slot = (slot + 1) & (hash_count - 1)
        else:
            raise AssertionError("Missing MPQ entry: " + name)
    print(f"Map built: {destination}, {len(actual):,} bytes, {len(entries)} MPQ files")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", type=Path, default=Path("."))
    p.add_argument("--output", type=Path, default=Path("dist/Hero_Arena_Reforged.w3x"))
    args = p.parse_args()
    build(args.source, args.output)
