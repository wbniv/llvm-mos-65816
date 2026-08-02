#!/usr/bin/env python3
"""Patch (or inspect) the SNES internal header of a .sfc image: map mode, ROM-size
byte, and checksum/complement -- for LoROM, HiROM and ExHiROM.

All address/size/mirroring knowledge lives in `tools/snes_cartmap.py`, the one
authoritative cartridge model; this tool is only the header writer/reader on top
of it. (Plan: docs/plans/2026-07-30-exhirom-video-boundary-test.md,
"Header, size, and checksum tooling".)

Mappings
--------
  --mapping lorom    (default; `--hirom` and `--exhirom` are shorthands)
      Header in the first 32 KiB at file $7FB0. Map mode $20. Up to 4 MiB.
  --mapping hirom
      Banks $C0+ map full 64 KiB, so the header is at file $FFB0. Map mode $21.
      Up to 4 MiB. Used by platforms/snes-hirom.
  --mapping exhirom
      Extended map: file $000000-$3FFFFF is reached through banks $C0-$FF, and
      file $400000+ through banks $40-$7D -- so the header and the reset vector
      the CPU fetches from $00:FFFC live at file $40FFB0/$40FFFC, in the SECOND
      region. Map mode $25. 4 MiB (exclusive) through 8 MiB. Used by
      platforms/snes-exhirom.
Speed
-----
Bit 4 of the map-mode byte is the cartridge bus SPEED, orthogonal to the
mapping: `--speed fast` (aliases `--fast`, `--fastrom`) selects the FastROM
variant of whichever mapping was chosen -- $30 / $31 / $35. The byte is derived
by the model (`CartMap.map_mode`); this tool never ORs the bit in itself.

Under `--inspect` the speed is read back from the header unless one is given
explicitly, so inspecting a FastROM image does not report a spurious map-mode
mismatch.

Sizes and physical devices
--------------------------
The image length is decomposed into at most two physical mask ROMs, largest
first (6 MiB = 32 Mbit + 16 Mbit). A length needing three or more chips, or not
a whole multiple of 32 KiB, is rejected -- it is not a buildable cartridge.

Checksum
--------
The internal checksum is taken over the LOGICAL image the address decoder sees:
the small device is mirrored across its slot until it is as large as the big one,
so a 4+2 MiB cartridge checksums as 8 MiB (`sum(big) + 2*sum(small)`), and the
ROM-size header byte describes that 8 MiB logical size (0x0D) -- which is what
the 48 Mbit commercial ExHiROM carts carry.

One pass suffices: the complement is pre-set to $FFFF and the checksum to $0000,
and those four placeholder bytes contribute the same constant to the sum as the
final values do (complement == checksum ^ $FFFF, so each byte pair sums to $FF).
That holds for the mirrored sum too, because the header is counted the same
number of times either way.

Usage
-----
  snes-checksum.py [--mapping M | --hirom | --exhirom] [--fastrom] <rom.sfc>
  snes-checksum.py --inspect [--mapping M] [--speed S] <rom.sfc>  # read-only
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from snes_cartmap import (  # noqa: E402
    CART_TYPE_ROM_ONLY,
    CART_TYPE_ROM_RAM,
    CART_TYPE_ROM_RAM_BATTERY,
    HEADER_FILE_OFFSET,
    MAPPINGS,
    REGION_BYTE,
    REGIONS,
    SPEEDS,
    OFF_CART_TYPE,
    OFF_CHECKSUM,
    OFF_COMPLEMENT,
    OFF_MAP_MODE,
    OFF_RAM_SIZE,
    OFF_REGION,
    OFF_RESET,
    OFF_ROM_SIZE,
    CartMap,
    video_standard_from_region_byte,
)

#: --ram convenience spellings -> bytes. The model's own ram_header_byte()
#: takes a raw byte count and would happily accept any power-of-two KiB size
#: it can express; this project's cartridges only ever use these four, so the
#: CLI only offers these four (an unlisted-but-legal size is still reachable
#: by calling tools/snes_cartmap.py's API directly).
RAM_SIZE_BYTES = {"none": 0, "2k": 2 << 10, "8k": 8 << 10, "32k": 32 << 10, "256k": 256 << 10}

TITLE_OFF = 0x10  # 21 ASCII bytes at $FFC0
TITLE_LEN = 21

#: Map-mode bytes belonging to cartridge families this project does NOT
#: implement. Recognised and reported, then refused -- so the packer fails
#: clearly instead of emitting a plausible-looking ROM for hardware whose
#: address decoder we have not modelled.
UNSUPPORTED_MAP_MODES = {
    0x22: "S-DD1", 0x32: "S-DD1 (fast)",
    0x23: "SA-1", 0x33: "SA-1 (fast)",
    0x2A: "SPC7110", 0x3A: "SPC7110 (fast)",
}
#: Cartridge-type bytes ($FFD6) that imply a coprocessor.
UNSUPPORTED_CART_TYPES = {
    0x03: "DSP", 0x05: "DSP + battery", 0x13: "SuperFX/GSU", 0x14: "SuperFX/GSU",
    0x15: "SuperFX/GSU + save", 0x1A: "SuperFX/GSU", 0x25: "OBC1", 0x32: "SA-1",
    0x34: "SA-1", 0x35: "SA-1", 0x43: "S-DD1", 0x45: "S-DD1 + save",
    0x55: "S-RTC", 0xE3: "Super Game Boy", 0xE5: "BS-X", 0xF3: "Cx4",
    0xF5: "ST018 / SPC7110", 0xF6: "ST010/ST011", 0xF9: "SPC7110 + RTC",
}


class HeaderError(Exception):
    pass


def load(path: str) -> bytearray:
    with open(path, "rb") as f:
        rom = bytearray(f.read())
    if len(rom) >= 512 and (len(rom) & 0x7FFF) == 512:
        raise HeaderError(
            f"{path}: image carries a 512-byte copier header ({len(rom)} bytes). "
            "This builder emits unheadered .sfc only; a copier header must never "
            "contaminate cartridge offsets or the checksum. Strip it first."
        )
    return rom


def infer_mapping(rom: bytes) -> str:
    """Pick the mapping the way bsnes-jg's heuristics will."""
    addr = CartMap.detect_header_address(bytes(rom))
    return {0x007FB0: "lorom", 0x00FFB0: "hirom",
            0x407FB0: "exlorom", 0x40FFB0: "exhirom"}[addr]


def check_unsupported(rom: bytes, base: int) -> list[str]:
    problems = []
    mode = rom[base + OFF_MAP_MODE]
    if mode in UNSUPPORTED_MAP_MODES:
        problems.append(
            f"map mode ${mode:02X} is {UNSUPPORTED_MAP_MODES[mode]} -- a cartridge that "
            "remaps memory with a coprocessor. Recognised, but not supported: it needs "
            "its own platform plan and fixtures."
        )
    ctype = rom[base + 0x26]
    if ctype in UNSUPPORTED_CART_TYPES:
        problems.append(
            f"cartridge type ${ctype:02X} is {UNSUPPORTED_CART_TYPES[ctype]} -- "
            "coprocessor/peripheral cartridges are out of scope for this mapper suite."
        )
    return problems


def structural_checks(cm: CartMap, rom: bytes, region: str | None = None,
                       ram: str | None = None, battery: bool = False) -> list[str]:
    """Header title and reset/vector structural checks (plan gate 2)."""
    base = cm.header_file_offset
    problems: list[str] = []

    if ram is not None:
        ram_bytes = RAM_SIZE_BYTES[ram]
        got_ram = rom[base + OFF_RAM_SIZE]
        want_ram = CartMap.ram_header_byte(ram_bytes)
        if got_ram != want_ram:
            problems.append(
                f"RAM-size byte ${got_ram:02X} != ${want_ram:02X} expected for --ram {ram}"
            )
        want_type = (
            CART_TYPE_ROM_ONLY if ram_bytes == 0
            else CART_TYPE_ROM_RAM_BATTERY if battery else CART_TYPE_ROM_RAM
        )
        got_type = rom[base + OFF_CART_TYPE]
        if got_type != want_type:
            problems.append(
                f"cartridge type byte ${got_type:02X} != ${want_type:02X} expected for "
                f"--ram {ram}{' --battery' if battery else ''}"
            )
        if ram_bytes:
            try:
                cm.ram_windows(ram_bytes)
            except ValueError as e:
                problems.append(f"SRAM aperture: {e}")

    if region is not None:
        got = rom[base + OFF_REGION]
        want = REGION_BYTE[region]
        if got != want:
            problems.append(
                f"region byte ${got:02X} != ${want:02X} expected for --region {region}"
            )
        elif video_standard_from_region_byte(got) != region:
            # Can only happen if REGION_BYTE and _NTSC_REGION_BYTES fall out of
            # sync with each other -- the two are independent tables (one is
            # this project's two choices, the other is bsnes-jg's full
            # heuristic set), so this guards against them silently disagreeing
            # on what "ntsc"/"pal" means for the byte this tool itself wrote.
            problems.append(
                f"region byte ${got:02X} was written for --region {region}, but "
                f"the bsnes-jg heuristic classifies it as {video_standard_from_region_byte(got)}"
            )

    title = rom[base + TITLE_OFF : base + TITLE_OFF + TITLE_LEN]
    if len(title) != TITLE_LEN or any(b < 0x20 or b > 0x7E for b in title):
        problems.append(
            f"title at ${base + TITLE_OFF:06X} is not 21 printable ASCII bytes: {title!r}"
        )

    reset = rom[base + OFF_RESET] | rom[base + OFF_RESET + 1] << 8
    if reset < 0x8000:
        problems.append(
            f"reset vector ${reset:04X} is below $8000; $00:0000-7FFF is never ROM"
        )
    else:
        try:
            off = cm.cpu_to_file(0x00, reset)
        except ValueError as e:
            problems.append(f"reset vector $00:{reset:04X} does not decode to ROM: {e}")
        else:
            opcode = rom[off]
            if opcode in (0x00, 0xFF):
                problems.append(
                    f"reset vector $00:{reset:04X} = file ${off:06X} holds ${opcode:02X}, "
                    "which is padding, not linked executable code"
                )

    # Native ($FFE4-$FFEF) and emulation ($FFF4-$FFFF) vectors that are wired up
    # must point into the near window, never at $0000.
    for name, voff in (("native NMI", 0x3A), ("native IRQ", 0x3E),
                       ("emu NMI", 0x4A), ("emu IRQ", 0x4E)):
        v = rom[base + voff] | rom[base + voff + 1] << 8
        if v and v < 0x8000:
            problems.append(f"{name} vector ${v:04X} is below $8000")

    if rom[base + OFF_MAP_MODE] != cm.map_mode:
        problems.append(
            f"map mode byte ${rom[base + OFF_MAP_MODE]:02X} != "
            f"${cm.map_mode:02X} expected for {cm.mapping}"
            f"{' (fast)' if cm.fast else ''}"
        )
    if rom[base + OFF_ROM_SIZE] != cm.rom_size_byte:
        problems.append(
            f"ROM-size byte ${rom[base + OFF_ROM_SIZE]:02X} != "
            f"${cm.rom_size_byte:02X} expected for a logical 0x{cm.logical_size:X} image"
        )

    stored_c = rom[base + OFF_COMPLEMENT] | rom[base + OFF_COMPLEMENT + 1] << 8
    stored_s = rom[base + OFF_CHECKSUM] | rom[base + OFF_CHECKSUM + 1] << 8
    want = cm.checksum(bytes(rom))
    if stored_s != want:
        problems.append(f"checksum ${stored_s:04X} != ${want:04X} recomputed")
    if (stored_s ^ 0xFFFF) != stored_c:
        problems.append(
            f"complement ${stored_c:04X} != ${stored_s ^ 0xFFFF:04X} (checksum ^ $FFFF)"
        )
    if cm.checksum(bytes(rom)) != cm.checksum_by_formula(bytes(rom)):
        problems.append("mirrored-image checksum disagrees with the multiplier formula")

    problems += check_unsupported(rom, base)
    return problems


def do_inspect(cm: CartMap, rom: bytes, path: str, region: str | None = None,
               ram: str | None = None, battery: bool = False) -> int:
    base = cm.header_file_offset
    title = bytes(rom[base + TITLE_OFF : base + TITLE_OFF + TITLE_LEN])
    reset = rom[base + OFF_RESET] | rom[base + OFF_RESET + 1] << 8
    stored_s = rom[base + OFF_CHECKSUM] | rom[base + OFF_CHECKSUM + 1] << 8
    stored_c = rom[base + OFF_COMPLEMENT] | rom[base + OFF_COMPLEMENT + 1] << 8

    print(f"{path}")
    print(cm.summary())
    print(f"title             : {title.decode('ascii', 'replace')!r}")
    print(f"map mode byte     : ${rom[base + OFF_MAP_MODE]:02X}")
    print(f"cartridge type    : ${rom[base + OFF_CART_TYPE]:02X}")
    print(f"ROM-size byte     : ${rom[base + OFF_ROM_SIZE]:02X}")
    ram_byte = rom[base + OFF_RAM_SIZE]
    print(f"RAM-size byte     : ${ram_byte:02X}  "
          f"({CartMap.ram_size_from_header_byte(ram_byte) // 1024} KiB save RAM)"
          if ram_byte else f"RAM-size byte     : ${ram_byte:02X}  (no save RAM)")
    print(f"region byte       : ${rom[base + OFF_REGION]:02X}  "
          f"(bsnes-jg videoRegion: {video_standard_from_region_byte(rom[base + OFF_REGION]).upper()})")
    try:
        roff = cm.cpu_to_file(0x00, reset)
        rwhere = f"file ${roff:06X} (first opcode ${rom[roff]:02X})"
    except ValueError:
        rwhere = "unmapped"
    print(f"reset vector      : $00:{reset:04X} -> {rwhere}")
    print("native vectors    : " + " ".join(
        f"{n}=${rom[base + o] | rom[base + o + 1] << 8:04X}"
        for n, o in (("COP", 0x34), ("BRK", 0x36), ("ABT", 0x38),
                     ("NMI", 0x3A), ("IRQ", 0x3E))))
    print("emu vectors       : " + " ".join(
        f"{n}=${rom[base + o] | rom[base + o + 1] << 8:04X}"
        for n, o in (("COP", 0x44), ("ABT", 0x48), ("NMI", 0x4A),
                     ("RES", 0x4C), ("IRQ", 0x4E))))
    print(f"checksum stored   : ${stored_s:04X}   complement ${stored_c:04X}")
    print(f"checksum recomputed: ${cm.checksum(bytes(rom)):04X} (mirrored image) "
          f"/ ${cm.checksum_by_formula(bytes(rom)):04X} (multiplier formula)")

    detected = infer_mapping(rom)
    scores = CartMap.detect_scores(bytes(rom))
    print(f"bsnes-jg heuristic: detects {detected}  "
          + "  ".join(f"{k}={v}" for k, v in scores.items()))
    if detected != cm.mapping:
        print(f"  !! an emulator will treat this image as {detected}, not {cm.mapping}")

    problems = structural_checks(cm, rom, region=region, ram=ram, battery=battery)
    if detected != cm.mapping:
        problems.append(f"header detected as {detected}, expected {cm.mapping}")
    if problems:
        print("\nFAIL:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print("\nPASS: header, size, decomposition, vectors and checksum all agree.")
    return 0


def do_patch(cm: CartMap, rom: bytearray, path: str, region: str = "ntsc",
             ram: str | None = None, battery: bool = False) -> int:
    base = cm.header_file_offset
    rom[base + OFF_MAP_MODE] = cm.map_mode
    rom[base + OFF_ROM_SIZE] = cm.rom_size_byte
    rom[base + OFF_REGION] = REGION_BYTE[region]
    # RAM-size/cartridge-type are untouched when --ram is not given at all --
    # unlike map mode/ROM size/region, this tool has never owned that field
    # (a coprocessor cartridge-type fixture pre-sets $FFD6 and expects the
    # patcher to leave it alone), so "own it" only activates on an explicit ask.
    if ram is not None:
        ram_bytes = RAM_SIZE_BYTES[ram]
        rom[base + OFF_RAM_SIZE] = CartMap.ram_header_byte(ram_bytes)
        rom[base + OFF_CART_TYPE] = (
            CART_TYPE_ROM_ONLY if ram_bytes == 0
            else CART_TYPE_ROM_RAM_BATTERY if battery else CART_TYPE_ROM_RAM
        )
        if ram_bytes:
            cm.ram_windows(ram_bytes)  # raises if this mapping's aperture can't fit it

    rom[base + OFF_COMPLEMENT : base + OFF_COMPLEMENT + 2] = b"\xff\xff"
    rom[base + OFF_CHECKSUM : base + OFF_CHECKSUM + 2] = b"\x00\x00"

    checksum = cm.checksum(bytes(rom))
    complement = checksum ^ 0xFFFF

    rom[base + OFF_COMPLEMENT] = complement & 0xFF
    rom[base + OFF_COMPLEMENT + 1] = complement >> 8
    rom[base + OFF_CHECKSUM] = checksum & 0xFF
    rom[base + OFF_CHECKSUM + 1] = checksum >> 8

    with open(path, "wb") as f:
        f.write(rom)

    devs = "+".join(d.label for d in cm.devices)
    print(f"{path}: {cm.mapping}{' (fast)' if cm.fast else ''} "
          f"size={len(rom) // 1024}KiB devices={devs} "
          f"map_mode=0x{rom[base + OFF_MAP_MODE]:02X} "
          f"rom_size_byte=0x{rom[base + OFF_ROM_SIZE]:02X} "
          f"ram_size_byte=0x{rom[base + OFF_RAM_SIZE]:02X} "
          f"cart_type=0x{rom[base + OFF_CART_TYPE]:02X} "
          f"checksum=0x{checksum:04X} complement=0x{complement:04X}")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="snes-checksum.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("rom")
    ap.add_argument("--mapping", choices=MAPPINGS)
    ap.add_argument("--hirom", action="store_true", help="shorthand for --mapping hirom")
    ap.add_argument("--exhirom", action="store_true", help="shorthand for --mapping exhirom")
    ap.add_argument("--speed", choices=SPEEDS,
                    help="cartridge bus speed; default slow when patching, "
                         "read from the header when inspecting")
    ap.add_argument("--fast", "--fastrom", dest="fast", action="store_true",
                    help="shorthand for --speed fast (--fastrom is the legacy spelling)")
    ap.add_argument("--region", choices=REGIONS,
                    help="video standard region byte ($FFD9-family offset); default ntsc "
                         "when patching. Under --inspect, an explicit value is enforced as a "
                         "structural check instead of just reported")
    ap.add_argument("--ram", choices=RAM_SIZE_BYTES,
                    help="save-RAM size ($FFD8 RAM-size byte + $FFD6 cartridge-type byte); "
                         "default none when patching. Under --inspect, an explicit value is "
                         "enforced as a structural check -- including that the size actually "
                         "fits the mapping's SRAM aperture (tools/snes_cartmap.py ram_windows)")
    ap.add_argument("--battery", action="store_true",
                    help="the save RAM is battery-backed, not volatile (requires --ram other "
                         "than none/absent)")
    ap.add_argument("--inspect", action="store_true",
                    help="read-only report + structural checks; patches nothing")
    args = ap.parse_args(argv[1:])

    if args.battery and args.ram in (None, "none"):
        print("error: --battery given without --ram; a battery backs SRAM, not nothing",
              file=sys.stderr)
        return 1

    mapping = args.mapping
    if args.hirom:
        mapping = "hirom"
    if args.exhirom:
        mapping = "exhirom"

    speed = "fast" if args.fast else args.speed

    try:
        rom = load(args.rom)
        if mapping is None:
            mapping = infer_mapping(rom) if args.inspect else "lorom"
            if mapping == "exlorom":
                raise HeaderError(
                    "image looks like unofficial ExLoROM, which this project does not "
                    "support; pass --mapping explicitly if that is wrong"
                )
        if speed is None:
            # Patching: the tool owns the header, and slow is the default board.
            # Inspecting: speed is a property of the image being read, so take it
            # from the byte -- otherwise every FastROM image would be reported as
            # a map-mode mismatch against a slow model it was never built as.
            if args.inspect:
                off = HEADER_FILE_OFFSET[mapping] + OFF_MAP_MODE
                if off >= len(rom):
                    raise HeaderError(
                        f"image is {len(rom)} bytes; too short to hold a {mapping} header"
                    )
                speed = CartMap.speed_from_map_mode(rom[off])
            else:
                speed = "slow"
        cm = CartMap(mapping, len(rom), speed=speed)
    except (HeaderError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if args.inspect:
        return do_inspect(cm, rom, args.rom, region=args.region, ram=args.ram,
                           battery=args.battery)
    return do_patch(cm, rom, args.rom, region=args.region or "ntsc",
                     ram=args.ram, battery=args.battery)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
