#!/usr/bin/env python3
"""Install a packed SVX2 stream at HiROM bank $C1 and emit a power-of-two image."""
from __future__ import annotations
import argparse
from pathlib import Path

BASE = 0x10000

parser = argparse.ArgumentParser()
parser.add_argument("rom", type=Path)
parser.add_argument("stream", type=Path)
args = parser.parse_args()
rom = bytearray(args.rom.read_bytes())
stream = args.stream.read_bytes()
used = max(len(rom), BASE + len(stream))
size = max(0x100000, 1 << (used - 1).bit_length())
if size > 0x400000:
    parser.error("runtime or stream exceeds the 4 MiB HiROM image")
rom.extend(bytes(size - len(rom)))
rom[BASE:BASE + len(stream)] = stream
args.rom.write_bytes(rom)
print(f"packed {len(stream)} stream bytes at file $010000; ROM={len(rom)} bytes")
