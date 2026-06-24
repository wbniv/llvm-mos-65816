#!/usr/bin/env python3
# tools/gen-snes-regmap.py — generate the SNES CPU-visible register-map reference
# (docs/refs/snes-hardware/snes-register-map.md) from the annotated HAL headers in
# platforms/snes/snes_*.h.
#
# The headers are the single source of truth. Each register carries an annotation
# block immediately above its #define:
#
#   |* @reg   INIDISP $2100 W  Display control 1 — force-blank + brightness.
#    * @bit   7        FBLANK   force blank (1 = screen off)
#    * @bits  3-0      BRIGHT   master brightness 0..15
#    *|
#   #define REG_INIDISP _SNES_REG8(0x2100)
#
# Use @reg16 for a 16-bit access alias laid over an L/H byte pair (e.g. REG_VMADD).
# The generator cross-checks that each annotation's $addr matches the 0xADDR in the
# #define, that the width tag (@reg/@reg16) matches the accessor (_SNES_REG8/16),
# and that bit ranges are in-range (0..7 for @reg, 0..15 for @reg16) and
# non-overlapping. Any mismatch is a hard error (exit 2) — that is the point: it
# keeps the docs honest about the headers. So edit the headers, regenerate, never
# hand-edit the .md.
#
#   tools/gen-snes-regmap.py > docs/refs/snes-hardware/snes-register-map.md
import argparse
import re
import sys
from pathlib import Path

# Subsystem header -> (section title, one-line blurb). Also fixes section order.
SECTIONS = [
    ("snes_ppu.h",    "PPU — Picture Processing Unit ($2100–$213F)",
     "Display, backgrounds, OAM, VRAM, Mode 7, CGRAM, windows, colour math, and the read ports."),
    ("snes_dma.h",    "DMA / HDMA ($4300–$437F, + $420B/$420C)",
     "Eight transfer channels plus the MDMAEN/HDMAEN enable triggers."),
    ("snes_cpu.h",    "CPU I/O — Ricoh 5A22 ($4200–$4217)",
     "Interrupt control, the hardware multiply/divide unit, the H/V IRQ timers, and FastROM select."),
    ("snes_joypad.h", "Controllers / Joypad ($4016–$4017, $4218–$421F)",
     "Serial controller access and the automatic-read pad latches."),
    ("snes_apu.h",    "APU ports — audio mailbox ($2140–$2143)",
     "The four ports to the (separate) SPC700/S-DSP audio processor."),
    ("snes_wram.h",   "WRAM access port ($2180–$2183)",
     "A CPU window into the full 128 KB of work RAM."),
]

RE_REG  = re.compile(r"@reg(16)?\s+(\w+)\s+\$([0-9A-Fa-f]+)\s+(RW|R|W)\s+(.*)")
RE_BIT  = re.compile(r"@bit\s+(\d+)\s+(\S+)\s*(.*)")
RE_BITS = re.compile(r"@bits\s+(\d+)-(\d+)\s+(\S+)\s*(.*)")
RE_DEF  = re.compile(r"#define\s+REG_(\w+)\s+_SNES_REG(8|16)\((0x[0-9A-Fa-f]+)\)")


def strip_comment(line: str) -> str:
    """Remove C block-comment framing (/*, *, */) and surrounding whitespace."""
    s = line.strip()
    if s.startswith("/*"):
        s = s[2:]
    if s.endswith("*/"):
        s = s[:-2]
    s = s.strip()
    if s.startswith("*"):
        s = s[1:].strip()
    return s


def esc(text: str) -> str:
    """Escape a Markdown table cell."""
    return text.strip().replace("|", "\\|")


def parse_header(path: Path) -> list[dict]:
    """Return a list of register dicts parsed from one subsystem header."""
    regs: list[dict] = []
    pending: dict | None = None
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        body = strip_comment(raw)

        m = RE_REG.search(body)
        if m:
            if pending is not None:
                sys.exit(f"{path.name}:{lineno}: @reg {m.group(2)} before previous "
                         f"@reg {pending['name']} got its #define")
            pending = {
                "name": m.group(2), "addr": int(m.group(3), 16),
                "width": 16 if m.group(1) else 8, "access": m.group(4),
                "purpose": m.group(5).strip(), "bits": [], "line": lineno,
            }
            continue

        if pending is not None:
            mb = RE_BITS.search(body)
            if mb:
                hi, lo = int(mb.group(1)), int(mb.group(2))
                pending["bits"].append((hi, lo, mb.group(3), mb.group(4).strip()))
                continue
            ms = RE_BIT.search(body)
            if ms:
                n = int(ms.group(1))
                pending["bits"].append((n, n, ms.group(2), ms.group(3).strip()))
                continue

        md = RE_DEF.search(raw)
        if md:
            name, width, addr = md.group(1), int(md.group(2)), int(md.group(3), 16)
            if pending is None:
                sys.exit(f"{path.name}:{lineno}: register REG_{name} has no @reg annotation")
            # --- self-consistency gates ---
            if name != pending["name"]:
                sys.exit(f"{path.name}:{lineno}: @reg {pending['name']} but #define REG_{name}")
            if addr != pending["addr"]:
                sys.exit(f"{path.name}:{lineno}: REG_{name} annotation $%04X != #define 0x%04X"
                         % (pending["addr"], addr))
            if width != pending["width"]:
                sys.exit(f"{path.name}:{lineno}: REG_{name} width tag @reg{pending['width']} "
                         f"!= _SNES_REG{width}")
            limit = 15 if width == 16 else 7
            seen = 0
            for hi, lo, _f, _d in pending["bits"]:
                if hi < lo or hi > limit or lo < 0:
                    sys.exit(f"{path.name}: REG_{name} bad bit range {hi}-{lo} (limit 0..{limit})")
                mask = ((1 << (hi - lo + 1)) - 1) << lo
                if seen & mask:
                    sys.exit(f"{path.name}: REG_{name} overlapping bit range {hi}-{lo}")
                seen |= mask
            regs.append(pending)
            pending = None
    if pending is not None:
        sys.exit(f"{path.name}: dangling @reg {pending['name']} with no #define")
    return regs


def fmt_bits(hi: int, lo: int) -> str:
    return f"{hi}" if hi == lo else f"{hi}-{lo}"


def emit(headers_dir: Path) -> str:
    out: list[str] = []
    out.append("<!-- generated by tools/gen-snes-regmap.py — DO NOT EDIT.")
    out.append("     Edit the platforms/snes/snes_*.h headers and regenerate:")
    out.append("       tools/gen-snes-regmap.py > docs/refs/snes-hardware/snes-register-map.md -->")
    out.append("")
    out.append("# SNES CPU-visible register map")
    out.append("")
    out.append("Every register the 65816 can reach directly (`$2100–$21FF`, `$4016–$43FF`), generated "
               "from the annotated HAL headers in `platforms/snes/snes_*.h` — the single source of "
               "truth. The audio processor (SPC700 + S-DSP) is reachable only through the four APU "
               "ports below and its internal registers are a separate address space (out of scope "
               "here; see the [hardware summary](snes-hardware-summary.md)). For the CPU core itself "
               "see the [65816 reference](../65816/65816-reference.md).")
    out.append("")
    out.append("Bit-field facts are per nocash *fullsnes*, the SNESdev wiki, and anomie's docs "
               "([SOURCES.md](SOURCES.md)).")
    out.append("")

    total = 0
    for fname, title, blurb in SECTIONS:
        path = headers_dir / fname
        if not path.exists():
            sys.exit(f"missing header: {path}")
        regs = parse_header(path)
        total += len(regs)
        out.append(f"## {title}")
        out.append("")
        out.append(f"{blurb} — `{fname}`, {len(regs)} registers.")
        out.append("")
        out.append("| Addr | Name | R/W | Purpose |")
        out.append("|------|------|-----|---------|")
        for r in regs:
            alias = " ¹⁶" if r["width"] == 16 else ""
            out.append(f"| `${r['addr']:04X}` | `REG_{r['name']}`{alias} | {r['access']} "
                       f"| {esc(r['purpose'])} |")
        out.append("")
        bitregs = [r for r in regs if r["bits"]]
        if bitregs:
            out.append("<details><summary>Bit fields</summary>")
            out.append("")
            for r in bitregs:
                out.append(f"**`${r['addr']:04X}` {r['name']}** — {esc(r['purpose'])}")
                out.append("")
                out.append("| Bits | Field | Meaning |")
                out.append("|------|-------|---------|")
                for hi, lo, field, desc in r["bits"]:
                    out.append(f"| {fmt_bits(hi, lo)} | `{field}` | {esc(desc)} |")
                out.append("")
            out.append("</details>")
            out.append("")
        out.append("¹⁶ = 16-bit access alias over the adjacent L/H byte pair." if any(
            r["width"] == 16 for r in regs) else "")
        out.append("")

    out.append("---")
    out.append("")
    out.append(f"*{total} registers across {len(SECTIONS)} subsystems.*")
    return "\n".join(out).rstrip() + "\n"


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description="Generate the SNES register-map .md from the HAL headers")
    ap.add_argument("--headers-dir", type=Path, default=root / "platforms" / "snes",
                    help="directory holding snes_*.h (default: platforms/snes)")
    args = ap.parse_args()
    sys.stdout.write(emit(args.headers_dir))


if __name__ == "__main__":
    main()
