#!/usr/bin/env python3
"""Patch the SNES internal-header ROM-size byte + checksum/complement of a LoROM .sfc image.

For a power-of-two ROM that fully fills its space, the checksum is simply the
sum of all bytes mod 0x10000, computed with the complement field pre-set to
0xFFFF and the checksum field to 0x0000 (which this build's header.s does). The
four placeholder bytes contribute a constant 0x1FE regardless of the final
value, so a single pass suffices.

Accepts 32 KiB (bank $00 only) or 64 KiB (banks $00+$01, #320 Increment 2b LoROM).
The ROM-size header byte is set from the image length (the tool owns it, so the
inherited header.s placeholder is corrected for whichever size was linked) — and
because it's set before the sum, the checksum covers the corrected byte.

Usage: snes-checksum.py <rom.sfc>
"""
import sys

# LoROM header offsets within bank $00 ($FFD7/$FFDC-$FFDF -> file 0x7FD7/0x7FDC).
# The header always lives in the first 32 KiB, so these are constant for both sizes.
ROMSIZE_OFF = 0x7FD7
COMPLEMENT_OFF = 0x7FDC
CHECKSUM_OFF = 0x7FDE

# ROM-size header byte = log2(size in KiB): 32 KiB -> 0x05, 64 KiB -> 0x06.
ROMSIZE_BYTE = {0x8000: 0x05, 0x10000: 0x06}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0 if "-h" in argv or "--help" in argv else 2

    path = argv[1]
    with open(path, "rb") as f:
        rom = bytearray(f.read())

    if len(rom) not in ROMSIZE_BYTE:
        print(f"error: expected a 32 KiB or 64 KiB LoROM image, got {len(rom)} bytes", file=sys.stderr)
        return 1

    # Set the ROM-size header byte from the actual image size (before summing, so
    # the checksum covers it), then ensure the checksum placeholders are
    # FF FF (complement) / 00 00 (checksum).
    rom[ROMSIZE_OFF] = ROMSIZE_BYTE[len(rom)]
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

    print(f"{path}: size={len(rom)//1024}KiB rom_size_byte=0x{rom[ROMSIZE_OFF]:02X} "
          f"checksum=0x{checksum:04X} complement=0x{complement:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
