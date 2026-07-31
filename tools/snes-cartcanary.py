#!/usr/bin/env python3
"""Generate the cartridge-size canary fixtures from the authoritative model.

Everything here is derived from `tools/snes_cartmap.py`: the linker script's
MEMORY regions and their file order, the canary sites, the segment lists for
spans that cross bank/device boundaries, and the expected values. Nothing
restates the mapping.

Three sub-commands:

  emit-platform  write <outdir>/link.ld and a mos-<name>.cfg into an SDK install,
                 so a size/mapping variant can be linked without an SDK rebuild.
  emit-header    write the C header of canary/segment descriptors the ROM reads.
  fill           post-link: write the deterministic pattern into every padding
                 byte, then report the expected oracle values.

The pattern
-----------
Every padding byte is `pattern(file_offset)` -- a function of the FULL 24-bit
file offset, so reading through the wrong mirror, the wrong bank, or with a
dropped bank-byte carry yields a different byte. That is what makes a mirror
probe a real probe rather than a coincidence.

Usage:
  snes-cartcanary.py emit-platform --mapping M --size S --name N --install DIR
  snes-cartcanary.py emit-header   --mapping M --size S --out FILE
  snes-cartcanary.py fill          --mapping M --size S --rom FILE [--json FILE]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from snes_cartmap import CartMap, parse_size  # noqa: E402

# --------------------------------------------------------------------------
# Deterministic padding pattern
# --------------------------------------------------------------------------
PATTERN_SALT = 0xA5

#: Cap on one emitted segment. The model allows a full 64 KiB bank, but the ROM
#: counts bytes in a 16-bit `unsigned int`, where 0x10000 truncates to 0.
SEG_MAX = 0x8000


def pattern(off: int) -> int:
    """Padding byte for a file offset.

    Depends on all 24 bits of the offset, so any bank/mirror confusion changes
    the byte -- and NON-LINEARLY, which matters more than it looks. The first
    version of this was `off ^ (off>>8) ^ (off>>16) ^ salt`, and every span fold
    came out $0000: an XOR-linear pattern XOR-folded over a power-of-two-aligned
    run is the XOR over an affine subspace, which is identically zero. Worse, it
    is zero for the WRONG bank too, so the oracle proved nothing. Only the host
    computes this, so a multiply-based mix costs nothing on console."""
    x = (off * 0x9E3779B1) & 0xFFFFFFFF
    x ^= x >> 15
    x = (x * 0x85EBCA6B) & 0xFFFFFFFF
    return (x ^ (x >> 13) ^ PATTERN_SALT) & 0xFF


def fold(h: int, b: int) -> int:
    """The 16-bit rolling fold the ROM computes: rotate left 1, then ADD.

    Order-sensitive (a swapped byte pair is caught) and, because the add carries
    between bit positions, not GF(2)-linear -- so it cannot collapse the way the
    XOR fold did. One `rol` + one 16-bit `adc` under +mos-a16."""
    h = ((h << 1) | (h >> 15)) & 0xFFFF
    return (h + b) & 0xFFFF


# --------------------------------------------------------------------------
# Linker layout, derived from the model
# --------------------------------------------------------------------------
NEAR_ORIGIN = 0x8000
NEAR_LENGTH = 0x7FB0
HDR_ORIGIN = 0xFFB0
HDR_LENGTH = 0x0050


class Region:
    def __init__(self, name: str, origin: int, length: int, file_start: int, note: str):
        self.name, self.origin, self.length = name, origin, length
        self.file_start, self.note = file_start, note

    @property
    def file_end(self) -> int:
        return self.file_start + self.length


def layout(cm: CartMap) -> list[Region]:
    """MEMORY regions in FILE order. Their concatenation is exactly the image,
    and each one's VMA is the canonical CPU address the model gives for its
    first file byte (except the deliberately-unreachable hole pads)."""
    regs: list[Region] = []
    if cm.mapping == "exhirom":
        regs.append(Region("rom_a", 0xC00000, 0x400000, 0x000000,
                           "region A: banks $C0-$FF, the first 4 MiB"))
        regs.append(Region("rom_blo", 0x400000, 0x8000, 0x400000,
                           "bank $40 low half -- not mirrored into bank $00"))
        regs.append(Region("rom", NEAR_ORIGIN, NEAR_LENGTH, 0x408000,
                           "near code: CPU $00:8000 == $40:8000"))
        regs.append(Region("romhdr", HDR_ORIGIN, HDR_LENGTH, 0x40FFB0,
                           "internal header + vectors"))
        tail = cm.size - 0x410000
        full = min(tail, (0x7E - 0x41) * 0x10000)
        regs.append(Region("rom_b", 0x410000, full, 0x410000,
                           "region B: banks $41-$7D"))
        rest = tail - full
        for i in range(rest // 0x10000):
            b = 0x3E + i
            regs.append(Region(f"pad_{b:02x}lo", b << 16, 0x8000,
                               0x410000 + full + i * 0x10000,
                               f"UNREACHABLE: bank ${b:02X} low half is behind WRAM"))
            regs.append(Region(f"rom_{b:02x}", (b << 16) | 0x8000, 0x8000,
                               0x410000 + full + i * 0x10000 + 0x8000,
                               f"bank ${b:02X} upper half -- the only window onto this 32 KiB"))
    elif cm.mapping == "hirom":
        regs.append(Region("rom_lopad", 0xC00000, 0x8000, 0x000000,
                           "unused low half of bank $C0"))
        regs.append(Region("rom", NEAR_ORIGIN, NEAR_LENGTH, 0x008000,
                           "near code: CPU $00:8000 == $C0:8000"))
        regs.append(Region("romhdr", HDR_ORIGIN, HDR_LENGTH, 0x00FFB0,
                           "internal header + vectors"))
        regs.append(Region("rom_far", 0xC10000, cm.size - 0x10000, 0x010000,
                           "far data: banks $C1 upward"))
    else:
        raise SystemExit(f"no canary layout for mapping {cm.mapping}")
    total = sum(r.length for r in regs)
    if total != cm.size:
        raise AssertionError(f"layout is {total} bytes, image is {cm.size}")
    at = 0
    for r in regs:
        if r.file_start != at:
            raise AssertionError(f"{r.name} starts at ${r.file_start:06X}, expected ${at:06X}")
        at += r.length
    return regs


def code_region(cm: CartMap) -> tuple[int, int]:
    """File range holding linked code + header -- the bytes `fill` must not touch."""
    regs = {r.name: r for r in layout(cm)}
    return regs["rom"].file_start, regs["romhdr"].file_end


def emit_linker_script(cm: CartMap) -> str:
    regs = layout(cm)
    devs = " + ".join(f"{d.label} @ ${d.file_start:06X}" for d in cm.devices)
    lines = [
        f"/* GENERATED by tools/snes-cartcanary.py from tools/snes_cartmap.py "
        f"({cm.mapping}, 0x{cm.size:X}). Do not edit by hand.",
        " *",
        f" * Mapping        : {cm.mapping}, map mode ${cm.map_mode:02X}",
        f" * Image          : {cm.size} bytes ({cm.size * 8 // 1024 // 1024} Mbit)",
        f" * Physical       : {devs}",
        f" * Header at file : ${cm.header_file_offset:06X}",
        " *",
        " * Canonical CPU windows (the ONE address a descriptor may name):",
    ]
    for w in cm.windows():
        lines.append(f" *   {w}")
    if cm.holes():
        lines.append(" *")
        lines.append(" * Addressing holes -- present in the file, unreachable by the CPU:")
        for s, e in cm.holes():
            lines.append(f" *   ${s:06X}-${e - 1:06X}")
    if cm.mapping == "exhirom":
        lines += [
            " *",
            " * Boot model: the 65816 resets with PBR=$00 and fetches RESET from $00:FFFC.",
            " * Under ExHiROM banks $00-$3F upper halves are the SECOND region, so that",
            " * fetch reads file $40FFFC and the near window $00:8000-$FFFF is file",
            " * $408000-$40FFFF -- i.e. the boot code lives in bank $40, not bank $C0.",
            " * The unchanged crt0 still runs: it only needs $00:8000-$FFFF to be ROM.",
        ]
    lines += [
        " */",
        "",
        "__rc0 = 0x00;",
        "INCLUDE imag-regs.ld",
        'ASSERT(__rc31 == 0x1f, "Inconsistent zero page map.")',
        "",
        "__stack = 0x2000;",
        "",
        "MEMORY {",
        "  zp     : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)",
        "  ram    : ORIGIN = 0x0200,     LENGTH = 0x1E00",
    ]
    width = max(len(r.name) for r in regs)
    for r in regs:
        lines.append(
            f"  {r.name:<{width}} : ORIGIN = 0x{r.origin:06X}, LENGTH = 0x{r.length:06X}"
            f"   /* file ${r.file_start:06X}-${r.file_end - 1:06X}  {r.note} */"
        )
    lines += [
        "}",
        "",
        'REGION_ALIAS("c_readonly", rom)',
        'REGION_ALIAS("c_writeable", ram)',
        "",
        "SECTIONS {",
        "  .text : { INCLUDE text-sections.ld } >c_readonly",
        "",
        "  INCLUDE rodata.ld",
        "  INCLUDE data.ld",
        "  INCLUDE zp.ld",
        "  INCLUDE bss.ld",
        "  INCLUDE noinit.ld",
        "",
        "  .ram (NOLOAD) : { *(.ram .ram.*) } >ram",
        "",
    ]
    far_region = "rom_b" if cm.mapping == "exhirom" else "rom_far"
    lines += [
        f"  .far_rodata : {{ *(.far_rodata .far_rodata.*) }} >{far_region}",
        f"  .far_text   : {{ *(.far_text .far_text.*)     }} >{far_region}",
        "",
        f"  .snes_header 0x{HDR_ORIGIN:04X} : {{ KEEP(*(.snes_header)) }} >romhdr",
        "",
        "  .snes_vectors_native 0xFFE0 : {",
        "    SHORT(0x0000) SHORT(0x0000)",
        "    SHORT(0x0000) SHORT(irq)",
        "    SHORT(0x0000) SHORT(nmi)",
        "    SHORT(0x0000) SHORT(irq)",
        "  } >romhdr",
        "",
        "  .snes_vectors_emu 0xFFF0 : {",
        "    SHORT(0x0000) SHORT(0x0000)",
        "    SHORT(0x0000) SHORT(0x0000)",
        "    SHORT(0x0000) SHORT(nmi)",
        "    SHORT(_start) SHORT(irq)",
        "  } >romhdr",
        "}",
        "",
        "/* Structural assertions: the header, the reset vector and both physical-ROM",
        " * boundaries must land where the model says, or the link fails loudly. */",
        f'ASSERT(ORIGIN(romhdr) == 0x{HDR_ORIGIN:04X}, "header not at $FFB0")',
        f'ASSERT(LENGTH(rom) + LENGTH(romhdr) == 0x8000, "near window is not 32 KiB")',
    ]
    for i, d in enumerate(cm.devices):
        owner = next(r for r in regs if r.file_start <= d.file_start < r.file_end)
        lines.append(
            f'ASSERT(ORIGIN({owner.name}) + '
            f"0x{d.file_start - owner.file_start:X} == 0x{cm.file_to_cpu(d.file_start)[0] << 16 | cm.file_to_cpu(d.file_start)[1]:06X}, "
            f'"physical ROM {i + 1} does not start at its modelled CPU address")'
        )
    lines += [
        "",
        "/* File order == the decoder model's offset order. */",
        "OUTPUT_FORMAT {",
    ]
    for r in regs:
        lines.append(f"  FULL({r.name})")
    lines += ["}", ""]
    return "\n".join(lines)


PLATFORM_CFG = """\
# GENERATED by tools/snes-cartcanary.py -- {name} ({mapping}, 0x{size:X} bytes).
# The -L below precedes @mos-snes.cfg's, so this platform's link.ld wins.
-L<CFGDIR>/../mos-platform/{name}/lib

@mos-snes.cfg
"""


# --------------------------------------------------------------------------
# Canary sites and spans
# --------------------------------------------------------------------------
class Canary:
    def __init__(self, tag: str, off: int, cm: CartMap):
        self.tag, self.off = tag, off
        self.bank, self.addr = cm.file_to_cpu(off)
        self.want = pattern(off)

    @property
    def far(self) -> int:
        return self.bank << 16 | self.addr


class Span:
    def __init__(self, tag: str, off: int, length: int, cm: CartMap):
        self.tag, self.off, self.length = tag, off, length
        self.segments: list[tuple[int, int, int]] = []  # (far addr, len, file offset)
        at, left = off, length
        while left:
            # `max_dma_span` is the model's truth: the run stops at the end of
            # the 64 KiB A-bus bank (the DMA source address does not carry into
            # the bank byte) and at the end of the canonical window. SEG_MAX
            # additionally caps a segment at 32 KiB so its length fits the ROM's
            # 16-bit loop counter -- a full 64 KiB bank would be 0x10000, which
            # truncates to 0 in a 16-bit `unsigned int`. Splitting only ever adds
            # a segment boundary; it never lets one straddle a bank.
            n = min(cm.max_dma_span(at), left, SEG_MAX)
            bank, addr = cm.file_to_cpu(at)
            self.segments.append((bank << 16 | addr, n, at))
            at += n
            left -= n
        assert all(0 < n <= 0xFFFF for _, n, _ in self.segments)
        for a, n, _ in self.segments:
            assert ((a & 0xFFFF) + n) <= 0x10000, f"{tag}: segment crosses a bank"
        self.want = 0
        for _, n, base in self.segments:
            for i in range(n):
                self.want = fold(self.want, pattern(base + i))

    @property
    def banks(self) -> int:
        return len({(a >> 16) for a, _, _ in self.segments})


def sites(cm: CartMap) -> tuple[list[Canary], list[Span]]:
    """Canary bytes at the first and last byte of every decoded window and every
    physical device, plus spans crossing one bank, several banks, and (for
    ExHiROM) the physical 4 MiB device boundary."""
    lo, hi = code_region(cm)

    def free(off: int, n: int = 1) -> bool:
        return not (off < hi and off + n > lo)

    canaries: list[Canary] = []
    seen: set[int] = set()

    def add(tag: str, off: int) -> None:
        if off in seen or not free(off):
            return
        seen.add(off)
        canaries.append(Canary(tag, off, cm))

    for i, w in enumerate(cm.windows()):
        add(f"WIN{i}_FIRST", w.file_start)
        add(f"WIN{i}_LAST", w.file_end - 1)
    for d in cm.devices:
        add(f"ROM{d.index + 1}_FIRST", d.file_start)
        add(f"ROM{d.index + 1}_LAST", d.file_end - 1)
    if cm.mapping == "exhirom":
        add("PRE_4M", 0x3FFFFF)
        add("POST_4M", 0x400000)
        add("ROM2_MID", 0x400000 + (cm.size - 0x400000) // 2)
    # One interior canary per 1 MiB divider, so every megabyte of the image is
    # proven addressable rather than only the window edges.
    for mb in range(1, cm.size >> 20):
        add(f"MIB_{mb}", mb << 20)

    spans: list[Span] = []
    # BANK_SPAN: dense, straddling exactly one 64 KiB CPU bank boundary.
    for cand in (0x00FF00, 0x01FF00):
        if free(cand, 0x400):
            spans.append(Span("BANK_SPAN", cand, 0x400, cm))
            break
    # MULTIBANK_SPAN: at least three CPU banks.
    base = 0x1FFF80 if cm.size > 0x300000 else 0x0FFF80
    if free(base, 0x20100):
        spans.append(Span("MULTIBANK_SPAN", base, 0x20100, cm))
    # EDGE_4M: begins below and ends above the physical 4 MiB boundary. In CPU
    # space that is a discontinuity ($FF:FFFF -> $40:0000), so it can only be
    # consumed through the segment list -- a single incrementing pointer fails.
    if cm.mapping == "exhirom" and free(0x3FFE00, 0x400):
        spans.append(Span("EDGE_4M", 0x3FFE00, 0x400, cm))
    # A span wholly inside the second device, crossing a bank there.
    if cm.mapping == "exhirom" and free(0x41FF00, 0x400):
        spans.append(Span("ROM2_BANK_SPAN", 0x41FF00, 0x400, cm))
    return canaries, spans


def mirror_probes(cm: CartMap) -> list[tuple[str, int, int, int]]:
    """(tag, canonical far addr, mirror far addr, expected byte).

    The two addresses must read the SAME byte -- and because the pattern depends
    on the file offset, a decoder that folded them to different offsets would be
    caught immediately."""
    out = []
    if cm.mapping == "exhirom":
        cases = [
            # Region A is reached by $C0-$FF and mirrored into the $80-$BF upper halves.
            ("MIRROR_A_80", (0xC0, 0x9000), (0x80, 0x9000)),
            ("MIRROR_A_BF", (0xFF, 0xFFFF), (0xBF, 0xFFFF)),
            # Region B is reached by $40-$7D and mirrored into the $00-$3F upper
            # halves -- the fact that makes the boot bank read the SECOND region.
            ("MIRROR_B_01", (0x41, 0x8000), (0x01, 0x8000)),
        ]
        if cm.size == 0x600000:
            # A 2 MiB device in a 4 MiB slot: $20-$3F repeat $00-$1F.
            cases.append(("MIRROR_B_21", (0x41, 0x9000), (0x21, 0x9000)))
    else:
        cases = [("MIRROR_01", (0xC1, 0x8000), (0x01, 0x8000)),
                 ("MIRROR_02", (0xC2, 0x9000), (0x02, 0x9000))]
    lo, hi = code_region(cm)
    for tag, (cb, ca), (mb, ma) in cases:
        off = cm.cpu_to_file(cb, ca)
        assert cm.cpu_to_file(mb, ma) == off, f"{tag}: not a mirror of the same byte"
        if lo <= off < hi:
            continue  # the byte is linked code, whose value the pattern does not own
        out.append((tag, cb << 16 | ca, mb << 16 | ma, pattern(off)))
    return out


# --------------------------------------------------------------------------
# Emitters
# --------------------------------------------------------------------------
def emit_header(cm: CartMap, label: str) -> str:
    canaries, spans = sites(cm)
    probes = mirror_probes(cm)
    segs: list[tuple[int, int]] = []
    span_rows = []
    for s in spans:
        span_rows.append((len(segs), len(s.segments), s.want, s.tag, s.length, s.banks))
        segs += [(a, n) for a, n, _ in s.segments]

    oracle = 0
    for c in canaries:
        oracle = fold(oracle, c.want)
    for _, _, _, want in probes:
        oracle = fold(oracle, want)
        oracle = fold(oracle, want)
    for start, n, want, *_ in span_rows:
        oracle = fold(oracle, want & 0xFF)
        oracle = fold(oracle, want >> 8)

    L = []
    A = L.append
    A("/* GENERATED by tools/snes-cartcanary.py -- do not edit.")
    A(f" * {label}: {cm.mapping}, 0x{cm.size:X} bytes, map mode ${cm.map_mode:02X}.")
    A(" * Every address below is a CANONICAL 24-bit CPU address produced by the")
    A(" * model's checked file->CPU inverse, never a raw file offset. */")
    A("#ifndef CARTSIZE_CANARY_DATA_H")
    A("#define CARTSIZE_CANARY_DATA_H")
    A("")
    A(f'#define CANARY_LABEL "{label}"')
    A(f"#define CANARY_IMAGE_BYTES 0x{cm.size:06X}u")
    A(f"#define CANARY_MAP_MODE 0x{cm.map_mode:02X}u")
    A(f"#define CANARY_ORACLE 0x{oracle:04X}u")
    A("")
    A(f"#define CANARY_COUNT {len(canaries)}")
    A("static const unsigned long canary_addr[CANARY_COUNT] = {")
    for c in canaries:
        A(f"  0x{c.far:06X}UL,  /* {c.tag}: file ${c.off:06X} = ${c.bank:02X}:{c.addr:04X} */")
    A("};")
    A("static const unsigned char canary_want[CANARY_COUNT] = {")
    A("  " + ", ".join(f"0x{c.want:02X}" for c in canaries))
    A("};")
    A("")
    A(f"#define PROBE_COUNT {len(probes)}")
    A("static const unsigned long probe_canonical[PROBE_COUNT] = {")
    for tag, canon, mirror, want in probes:
        A(f"  0x{canon:06X}UL,  /* {tag} */")
    A("};")
    A("static const unsigned long probe_mirror[PROBE_COUNT] = {")
    for tag, canon, mirror, want in probes:
        A(f"  0x{mirror:06X}UL,")
    A("};")
    A("static const unsigned char probe_want[PROBE_COUNT] = {")
    A("  " + ", ".join(f"0x{w:02X}" for _, _, _, w in probes))
    A("};")
    A("")
    A(f"#define SEG_COUNT {len(segs)}")
    A("static const unsigned long seg_addr[SEG_COUNT] = {")
    A("  " + ", ".join(f"0x{a:06X}UL" for a, _ in segs))
    A("};")
    A("static const unsigned int seg_len[SEG_COUNT] = {")
    A("  " + ", ".join(f"0x{n:04X}u" for _, n in segs))
    A("};")
    A("")
    A(f"#define SPAN_COUNT {len(span_rows)}")
    A("static const unsigned char span_first[SPAN_COUNT] = {")
    A("  " + ", ".join(str(r[0]) for r in span_rows))
    A("};")
    A("static const unsigned char span_nseg[SPAN_COUNT] = {")
    A("  " + ", ".join(str(r[1]) for r in span_rows))
    A("};")
    A("static const unsigned int span_want[SPAN_COUNT] = {")
    for start, n, want, tag, length, banks in span_rows:
        A(f"  0x{want:04X}u,  /* {tag}: {length} bytes, {n} segment(s), {banks} CPU bank(s) */")
    A("};")
    A("")
    A("#endif")
    A("")
    return "\n".join(L)


def fill_ranges(cm: CartMap) -> list[tuple[int, int]]:
    """The file ranges the ROM actually reads -- every canary byte, every mirror
    probe's byte, and every span -- merged and sorted. These are the only bytes
    whose value is ever compared, so they are the only bytes that need the
    discriminating pattern."""
    canaries, spans = sites(cm)
    raw = [(c.off, c.off + 1) for c in canaries]
    raw += [(s.off, s.off + s.length) for s in spans]
    for _, canon, _, _ in mirror_probes(cm):
        off = cm.cpu_to_file(canon >> 16, canon & 0xFFFF)
        raw.append((off, off + 1))
    out: list[tuple[int, int]] = []
    for start, end in sorted(raw):
        if out and start <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], end))
        else:
            out.append((start, end))
    return out


def do_fill(cm: CartMap, path: str) -> dict:
    with open(path, "rb") as f:
        rom = bytearray(f.read())
    if len(rom) != cm.size:
        raise SystemExit(
            f"{path}: linked image is {len(rom)} bytes, model expects {cm.size}"
        )
    lo, hi = code_region(cm)
    # Padding is deterministic, and deliberately SPARSE: the discriminating
    # pattern goes only where a canary, a mirror probe or a span actually reads;
    # everything else is zero. Nothing is weakened -- an untested byte's value is
    # never compared -- and it buys two things. The image compresses to tens of
    # KiB over the wire instead of 6-8 MiB of incompressible hash, which matters
    # because these ROMs are published to an in-browser player. And zero padding
    # cannot accidentally score as a cartridge header at $7FB0/$FFB0/$407FB0
    # (bsnes rejects a reset vector below $8000 outright), so the mapping is
    # detected on its real header alone.
    rom[0:lo] = bytes(lo)
    rom[hi:cm.size] = bytes(cm.size - hi)
    for start, end in fill_ranges(cm):
        rom[start:end] = bytes(pattern(o) for o in range(start, end))
    with open(path, "wb") as f:
        f.write(rom)

    canaries, spans = sites(cm)
    # Read the canaries back OUT of the written file through the model, which is
    # the host half of the same check the ROM performs on console.
    for c in canaries:
        got = rom[cm.cpu_to_file(c.far >> 16, c.far & 0xFFFF)]
        if got != c.want:
            raise SystemExit(
                f"{c.tag}: file ${c.off:06X} holds ${got:02X}, expected ${c.want:02X}"
            )
    for s in spans:
        h = 0
        for a, n, _ in s.segments:
            base = cm.cpu_to_file(a >> 16, a & 0xFFFF)
            for i in range(n):
                h = fold(h, rom[base + i])
        if h != s.want:
            raise SystemExit(f"{s.tag}: host re-read fold ${h:04X} != ${s.want:04X}")
    return {
        "size": cm.size,
        "code_range": [lo, hi],
        "canaries": [{"tag": c.tag, "file": c.off, "cpu": c.far, "want": c.want}
                     for c in canaries],
        "spans": [{"tag": s.tag, "file": s.off, "len": s.length,
                   "segments": [[a, n] for a, n, _ in s.segments],
                   "banks": s.banks, "want": s.want} for s in spans],
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="snes-cartcanary.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("emit-platform", "emit-header", "fill"):
        p = sub.add_parser(name)
        p.add_argument("--mapping", required=True)
        p.add_argument("--size", type=parse_size, required=True)
        if name == "emit-platform":
            p.add_argument("--name", required=True)
            p.add_argument("--install", required=True)
        if name == "emit-header":
            p.add_argument("--out", required=True)
            p.add_argument("--label", default="")
        if name == "fill":
            p.add_argument("--rom", required=True)
            p.add_argument("--json")
    args = ap.parse_args(argv[1:])
    cm = CartMap(args.mapping, args.size)

    if args.cmd == "emit-platform":
        libdir = os.path.join(args.install, "mos-platform", args.name, "lib")
        os.makedirs(libdir, exist_ok=True)
        with open(os.path.join(libdir, "link.ld"), "w") as f:
            f.write(emit_linker_script(cm))
        cfg = os.path.join(args.install, "bin", f"mos-{args.name}.cfg")
        with open(cfg, "w") as f:
            f.write(PLATFORM_CFG.format(name=args.name, mapping=cm.mapping, size=cm.size))
        print(f"platform {args.name}: {libdir}/link.ld + {cfg}")
        return 0

    if args.cmd == "emit-header":
        label = args.label or f"{cm.mapping} {cm.size // 1024 // 1024} MiB"
        with open(args.out, "w") as f:
            f.write(emit_header(cm, label))
        canaries, spans = sites(cm)
        print(f"header {args.out}: {len(canaries)} canaries, {len(spans)} spans "
              f"({sum(len(s.segments) for s in spans)} segments), "
              f"{len(mirror_probes(cm))} mirror probes")
        return 0

    report = do_fill(cm, args.rom)
    if args.json:
        with open(args.json, "w") as f:
            json.dump(report, f, indent=2)
    print(f"fill {args.rom}: {report['size']} bytes, code ${report['code_range'][0]:06X}-"
          f"${report['code_range'][1] - 1:06X}, {len(report['canaries'])} canaries verified, "
          f"{len(report['spans'])} spans verified")
    for s in report["spans"]:
        print(f"    {s['tag']:<16} file ${s['file']:06X} +{s['len']:<6} "
              f"{len(s['segments'])} segment(s) across {s['banks']} bank(s) -> fold ${s['want']:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
