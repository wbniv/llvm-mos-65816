#!/usr/bin/env python3
"""Patch the SNES internal-header checksum/complement of a LoROM .sfc image.

For a power-of-two ROM that fully fills its space, the checksum is simply the
sum of all bytes mod 0x10000, computed with the complement field pre-set to
0xFFFF and the checksum field to 0x0000 (which this build's header.s does). The
four placeholder bytes contribute a constant 0x1FE regardless of the final
value, so a single pass suffices.

Usage: snes-checksum.py <rom.sfc>
"""
import sys

# LoROM header offsets within the 32 KiB image ($FFDC-$FFDF -> file 0x7FDC).
COMPLEMENT_OFF = 0x7FDC
CHECKSUM_OFF = 0x7FDE


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0 if "-h" in argv or "--help" in argv else 2

    path = argv[1]
    with open(path, "rb") as f:
        rom = bytearray(f.read())

    if len(rom) != 0x8000:
        print(f"error: expected a 32 KiB LoROM image, got {len(rom)} bytes", file=sys.stderr)
        return 1

    # Ensure placeholders are FF FF (complement) / 00 00 (checksum).
    rom[COMPLEMENT_OFF:COMPLEMENT_OFF + 2] = b"\xff\xff"
    rom[CHECKSUM_OFF:CHECKSUM_OFF + 2] = b"\x00\x00"

    checksum = sum(rom) & 0xFFFF
    complement = checksum ^ 0xFFFF

    rom[COMPLEMENT_OFF] = complement & 0xFF
    rom[COMPLEMENT_OFF + 1] = complement >> 8
    rom[CHECKSUM_OFF] = checksum & 0xFF
    rom[CHECKSUM_OFF + 1] = checksum >> 8

    with open(path, "wb") as f:
        f.write(rom)

    print(f"{path}: checksum=0x{checksum:04X} complement=0x{complement:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
