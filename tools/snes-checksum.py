#!/usr/bin/env python3
"""Patch the SNES internal-header map-mode + ROM-size byte + checksum/complement of a .sfc image.

For a power-of-two ROM that fully fills its space, the checksum is simply the
sum of all bytes mod 0x10000, computed with the complement field pre-set to
0xFFFF and the checksum field to 0x0000 (which this build's header.s does). The
four placeholder bytes contribute a constant 0x1FE regardless of the final
value, so a single pass suffices.

LoROM (default): the internal header lives in the first 32 KiB at file 0x7FB0-0x7FFF.
Accepts 32 KiB (bank $00), 64 KiB (banks $00+$01, #320 Increment 2b LoROM), 128 KiB,
256 KiB, 512 KiB, 1 MiB, 2 MiB, or 4 MiB — all power-of-two
LoROM images that fully fill their space, so the simple sum-of-all-bytes checksum holds.

HiROM (--hirom): banks $C0+ map the full 64 KiB contiguously, so the header lives at
file 0xFFB0-0xFFFF (bank $C0). Used by platforms/snes-hirom (libfixmath's ~200 KiB sin
LUT in far rodata). Sets map-mode byte 0x21 (LoROM is 0x20, left as header.s emits it).

The ROM-size header byte is set from the image length (the tool owns it, so the inherited
header.s placeholder is corrected for whichever size/mapping was linked), before the sum, so
the checksum covers the corrected bytes.

Use --fastrom to set the mapping's speed bit after selecting LoROM or HiROM.

Usage: snes-checksum.py [--hirom] [--fastrom] <rom.sfc>
"""
import sys


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("-")]
    hirom = "--hirom" in argv
    fastrom = "--fastrom" in argv
    if len(args) != 1 or "-h" in argv or "--help" in argv:
        print(__doc__)
        return 0 if ("-h" in argv or "--help" in argv) else 2

    path = args[0]
    with open(path, "rb") as f:
        rom = bytearray(f.read())

    if hirom:
        # Header at file 0xFFB0-0xFFFF (bank $C0). Map-mode 0x21 = HiROM.
        base = 0xFFB0
        if len(rom) < 0x10000 or (len(rom) & (len(rom) - 1)) != 0:
            print(f"error: --hirom expects a power-of-two image >= 64 KiB, got {len(rom)} bytes", file=sys.stderr)
            return 1
    else:
        # LoROM header lives in the first 32 KiB regardless of total size.
        base = 0x7FB0
        if len(rom) not in (0x8000, 0x10000, 0x20000, 0x40000, 0x80000,
                            0x100000, 0x200000, 0x400000):
            print(f"error: expected a power-of-two LoROM image from 32 KiB through 4096 KiB, got {len(rom)} bytes", file=sys.stderr)
            return 1

    MAPMODE_OFF = base + 0x25      # $FFD5
    ROMSIZE_OFF = base + 0x27      # $FFD7
    COMPLEMENT_OFF = base + 0x2C   # $FFDC
    CHECKSUM_OFF = base + 0x2E     # $FFDE

    # ROM-size header byte = round(log2(size in KiB)): 32->0x05, 64->0x06, 128->0x07,
    # 256->0x08, 512->0x09, 1024->0x0A.
    size_kib = len(rom) // 1024
    rom[ROMSIZE_OFF] = size_kib.bit_length() - 1

    # The checksum tool owns the complete mapping byte, not merely the speed bit;
    # this also repairs blank or stale header placeholders deterministically.
    rom[MAPMODE_OFF] = 0x21 if hirom else 0x20
    if fastrom:
        rom[MAPMODE_OFF] |= 0x10   # FastROM speed bit: LoROM $30 / HiROM $31

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

    print(f"{path}: {'FastROM ' if fastrom else ''}{'HiROM' if hirom else 'LoROM'} size={size_kib}KiB "
          f"map_mode=0x{rom[MAPMODE_OFF]:02X} rom_size_byte=0x{rom[ROMSIZE_OFF]:02X} "
          f"checksum=0x{checksum:04X} complement=0x{complement:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
