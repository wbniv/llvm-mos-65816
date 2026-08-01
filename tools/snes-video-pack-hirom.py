#!/usr/bin/env python3
"""Install a packed SVX2 stream at HiROM bank $C1 and emit a 1 MiB image."""
from __future__ import annotations
import argparse
from pathlib import Path

BASE = 0x10000
SIZE = 0x100000

parser = argparse.ArgumentParser()
parser.add_argument("rom", type=Path)
parser.add_argument("stream", type=Path)
args = parser.parse_args()
rom = bytearray(args.rom.read_bytes())
stream = args.stream.read_bytes()
if len(rom) > SIZE or BASE + len(stream) > SIZE:
    parser.error("runtime or stream exceeds the 1 MiB HiROM image")
rom.extend(bytes(SIZE - len(rom)))
rom[BASE:BASE + len(stream)] = stream
args.rom.write_bytes(rom)
print(f"packed {len(stream)} stream bytes at file $010000; ROM={len(rom)} bytes")
