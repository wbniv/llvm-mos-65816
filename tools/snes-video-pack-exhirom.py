#!/usr/bin/env python3
"""Install an SVX2 stream around ExHiROM's FastROM and boot windows."""

from __future__ import annotations

import argparse
from pathlib import Path


FAST_CODE_SOURCE = 0x400000
FAST_CODE_END = 0x410000
STREAM_A = 0x010000
REGION_A_END = 0x400000
STREAM_B = 0x410000
IMAGE_SIZE = 0x800000

parser = argparse.ArgumentParser()
parser.add_argument("rom", type=Path)
parser.add_argument("stream", type=Path)
args = parser.parse_args()
rom = bytearray(args.rom.read_bytes())
stream = args.stream.read_bytes()
capacity = (REGION_A_END - STREAM_A) + (IMAGE_SIZE - STREAM_B)
if len(stream) > capacity:
    parser.error(f"stream exceeds ExHiROM packed capacity by {len(stream) - capacity} bytes")
if len(rom) > IMAGE_SIZE:
    parser.error("linked image exceeds 8 MiB")
if len(rom) < FAST_CODE_END:
    parser.error("linked image does not contain the complete ExHiROM bank-$40 code window")
reset = int.from_bytes(rom[0x40FFFC:0x40FFFE], "little")
if reset < 0x8000:
    parser.error(f"invalid ExHiROM reset vector ${reset:04X}")
if not any(rom[0x408000:0x40FFB0]):
    parser.error("linked ExHiROM near-code window is empty")
rom.extend(bytes(IMAGE_SIZE - len(rom)))
# The program links into ExHiROM's bank-$40 near/boot window.  Mirror that
# complete 64 KiB bank into file bank $C0 so the FastROM trampoline can enter
# $C0 while retaining identical 16-bit code and data addresses.
rom[0:0x10000] = rom[FAST_CODE_SOURCE:FAST_CODE_END]
first_capacity = REGION_A_END - STREAM_A
first = min(len(stream), first_capacity)
if STREAM_A + first > REGION_A_END:
    parser.error("stream part A overlaps the ExHiROM boot window")
if STREAM_B + len(stream) - first > IMAGE_SIZE:
    parser.error("stream part B exceeds the ExHiROM image")
rom[STREAM_A:STREAM_A + first] = stream[:first]
rom[STREAM_B:STREAM_B + len(stream) - first] = stream[first:]
args.rom.write_bytes(rom)
print(f"mirrored FastROM code at file $000000-$00FFFF; packed {len(stream)} "
      f"stream bytes at $010000-$3FFFFF then $410000; ROM={len(rom)} bytes")
