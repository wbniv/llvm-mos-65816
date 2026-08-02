#!/usr/bin/env python3
"""Render the SNES cartridge decode map as a self-contained inline SVG.

Every coordinate in the picture comes from `tools/snes_cartmap.py`'s
`CartMap.decode_cells()` / `.windows()` / `.holes()` / `.physical()` -- this
file draws what the model reports, it does not restate any address. That is
the same "one authoritative model" discipline `snes_cartmap.py` documents for
the linker/checksum/canary tools; this is the same thing for a picture.

The picture folds the 256-bank x 2-half-bank CPU address space into a 16x16
hex grid (row = bank >> 4, column = bank & 0xF, matching how the banks are
written everywhere else in this repo's docs), with each bank split into its
lower ($0000-$7FFF) and upper ($8000-$FFFF) half. Every one of the 512 half-
bank cells is classified into exactly one of:

    rom (canonical)   -- the one CPU address `file_to_cpu()` hands back
    rom (mirror)      -- same file bytes, a different CPU address
    WRAM              -- banks $7E/$7F, hard-wired, never cartridge
    system area / I-O -- the low half of banks below $C0 that isn't ROM
    unreachable hole  -- physically present file bytes no CPU address reaches
                         (the 8 MiB ExHiROM tail; see `CartMap.holes()`)

Usage:
    snes-cartmap-viz.py --mapping exhirom --size 6M            # SVG to stdout
    snes-cartmap-viz.py --mapping exhirom --size 6M --out x.svg
    snes-cartmap-viz.py --selftest                             # regression check, no output
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
from snes_cartmap import CartMap, WRAM_BANKS, parse_size  # noqa: E402

# --------------------------------------------------------------------------
# Palette. Canonical = saturated device colour; mirror = the same hue, light.
# Kept to two device slots because `snes_cartmap.decompose()` caps a cartridge
# at MAX_DEVICES == 2.
# --------------------------------------------------------------------------
DEVICE_COLORS = (
    {"canonical": "#2f6fed", "mirror": "#c7d9fb", "stroke": "#1d4fbf"},
    {"canonical": "#e0900b", "mirror": "#f6dfb3", "stroke": "#a86800"},
)
WRAM_COLOR = "#52525b"
WRAM_STROKE = "#33333a"
UNMAPPED_COLOR = "#eef1f4"
UNMAPPED_STROKE = "#c7ccd1"
HOLE_COLOR = "#fca5a5"
HOLE_STROKE = "#b91c1c"
TEXT_COLOR = "#1b1f24"
MUTED_COLOR = "#5b6470"
GRID_LABEL_COLOR = "#8a93a0"
BG_COLOR = "#ffffff"

FONT = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

# --------------------------------------------------------------------------
# Grid geometry: 16 columns (bank low nibble) x 16 rows (bank high nibble),
# each bank cell split into a top (addr $0000) and bottom (addr $8000) half.
# --------------------------------------------------------------------------
COLS, ROWS = 16, 16
CELL_W, CELL_GAP = 36, 3
HALF_H, ROW_GAP = 8, 3
GRID_LEFT = 30
COL_LABEL_H = 14

CANVAS_W = GRID_LEFT + COLS * (CELL_W + CELL_GAP) - CELL_GAP + 12


class Doc:
    """Tiny append-only SVG body builder with a running y-cursor."""

    def __init__(self, width: int):
        self.width = width
        self.parts: list[str] = []
        self.y = 0
        self.max_x = width

    def raw(self, s: str) -> None:
        self.parts.append(s)

    def text(self, x: float, y: float, s: str, size: int = 12, weight: str = "normal",
              fill: str = TEXT_COLOR, family: str = FONT, anchor: str = "start") -> None:
        self.raw(
            f'<text x="{x:.1f}" y="{y:.1f}" font-family="{family}" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>'
        )

    def rect(self, x: float, y: float, w: float, h: float, fill: str, stroke: str = "none",
              stroke_width: float = 0.6, extra: str = "") -> None:
        self.raw(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{stroke_width}" {extra}/>'
        )

    def line_block(self, lines: list[str], x: float, size: int = 12, leading: int = 15,
                    fill: str = TEXT_COLOR, weight: str = "normal") -> None:
        for line in lines:
            self.y += leading
            self.text(x, self.y, line, size=size, fill=fill, weight=weight)

    def wrapped_block(self, lines: list[str], x: float, size: int = 11, leading: int = 15,
                        fill: str = TEXT_COLOR, weight: str = "normal") -> None:
        """Like `line_block`, but word-wraps each input line to fit the canvas
        width first -- for prose (counts summary, seam callouts) that can run
        well past a monospace address line's length."""
        avail = self.width - x - 12
        for line in lines:
            self.line_block(wrap_text(line, avail, size), x, size=size,
                             leading=leading, fill=fill, weight=weight)


def wrap_text(text: str, width_px: float, size: int) -> list[str]:
    """Greedy word-wrap sized for the monospace font: ~0.62 * font-size per
    character is a safe upper bound for this font stack at normal weight."""
    max_chars = max(20, int(width_px / (size * 0.62)))
    words = text.split(" ")
    lines: list[str] = []
    cur = ""
    for word in words:
        cand = f"{cur} {word}".strip()
        if len(cand) > max_chars and cur:
            lines.append(cur)
            cur = word
        else:
            cur = cand
    if cur:
        lines.append(cur)
    return lines


def classify_cells(cm: CartMap):
    """Return (cellmap, hole_banks) -- both derived, nothing hand-addressed.

    `cellmap[(bank, addr_lo)]` is the `DecodeCell` for every half-bank the
    decoder maps at all (canonical or mirror). `hole_banks` is the set of
    banks whose upper half is a canonical ExHiROM-tail window but whose lower
    half decodes to nothing -- i.e. the "unreachable hole" cells -- found by
    asking the model, not by naming $3E/$3F.
    """
    cellmap = {c.key: c for c in cm.decode_cells()}
    hole_banks = set()
    for w in cm.windows():
        if w.addr_lo == 0x8000 and w.bank_lo == w.bank_hi:
            if (w.bank_lo, 0x0000) not in cellmap:
                hole_banks.add(w.bank_lo)
    return cellmap, hole_banks


def classify(bank: int, addr_lo: int, cellmap, hole_banks):
    """-> one of 'rom', 'wram', 'hole', 'unmapped', plus payload."""
    cell = cellmap.get((bank, addr_lo))
    if cell is not None:
        return "rom", cell
    if bank in WRAM_BANKS:
        return "wram", None
    if addr_lo == 0x0000 and bank in hole_banks:
        return "hole", None
    return "unmapped", None


def build_svg(mapping: str, size: int, label: str) -> tuple[str, dict]:
    cm = CartMap(mapping, size)
    cellmap, hole_banks = classify_cells(cm)

    counts = {"canonical": 0, "mirror": 0, "wram": 0, "unmapped": 0, "hole": 0}
    d = Doc(CANVAS_W)

    # ---- header ----------------------------------------------------------
    d.y = 22
    d.text(GRID_LEFT, d.y, f"{label} — CPU bank decode map", size=15, weight="bold")
    d.y += 3
    devs = ", ".join(f"ROM {dev.index + 1} = {dev.label} @ file ${dev.file_start:06X}"
                      for dev in cm.devices)
    d.wrapped_block(
        [f"mapping {cm.mapping} (map mode ${cm.map_mode:02X}, {cm.speed} ROM) — {devs}"],
        GRID_LEFT, size=11, leading=14, fill=MUTED_COLOR,
    )

    # ---- grid --------------------------------------------------------------
    d.y += 20
    grid_top = d.y + COL_LABEL_H
    for col in range(COLS):
        x = GRID_LEFT + col * (CELL_W + CELL_GAP) + CELL_W / 2
        d.text(x, grid_top - 4, f"{col:X}", size=10, fill=GRID_LABEL_COLOR, anchor="middle")

    bank_row_h = 2 * HALF_H + ROW_GAP
    for row in range(ROWS):
        y = grid_top + row * bank_row_h
        d.text(GRID_LEFT - 6, y + HALF_H + 3, f"${row:X}0", size=9,
               fill=GRID_LABEL_COLOR, anchor="end")
        for col in range(COLS):
            bank = row * 16 + col
            x = GRID_LEFT + col * (CELL_W + CELL_GAP)
            for half, addr_lo in ((0, 0x0000), (1, 0x8000)):
                kind, payload = classify(bank, addr_lo, cellmap, hole_banks)
                cy = y + half * HALF_H
                if kind == "rom":
                    dev_idx, _off = cm.physical(payload.file_start)
                    pal = DEVICE_COLORS[dev_idx]
                    if payload.canonical:
                        fill, stroke = pal["canonical"], pal["stroke"]
                        counts["canonical"] += 1
                    else:
                        fill, stroke = pal["mirror"], pal["stroke"]
                        counts["mirror"] += 1
                elif kind == "wram":
                    fill, stroke = WRAM_COLOR, WRAM_STROKE
                    counts["wram"] += 1
                elif kind == "hole":
                    fill, stroke = HOLE_COLOR, HOLE_STROKE
                    counts["hole"] += 1
                else:
                    fill, stroke = UNMAPPED_COLOR, UNMAPPED_STROKE
                    counts["unmapped"] += 1
                d.rect(x, cy, CELL_W, HALF_H, fill, stroke, stroke_width=0.5)
    grid_bottom = grid_top + ROWS * bank_row_h
    d.y = grid_bottom

    # ---- legend ------------------------------------------------------------
    d.y += 22
    legend = []
    for dev in cm.devices:
        pal = DEVICE_COLORS[dev.index]
        legend.append((pal["canonical"], pal["stroke"],
                        f"ROM {dev.index + 1} canonical — {dev.label} @ "
                        f"file ${dev.file_start:06X}–${dev.file_end - 1:06X}"))
        legend.append((pal["mirror"], pal["stroke"],
                        f"ROM {dev.index + 1} mirror — same bytes, alternate CPU address"))
    legend.append((WRAM_COLOR, WRAM_STROKE, "WRAM ($7E/$7F) — hard-wired, never cartridge"))
    legend.append((UNMAPPED_COLOR, UNMAPPED_STROKE,
                    "system area / I-O — bank low half below $C0, not cartridge"))
    if hole_banks:
        hole_bytes = len(hole_banks) * CartMap.CELL
        legend.append((HOLE_COLOR, HOLE_STROKE,
                        f"unreachable — {hole_bytes // 1024} KiB physically present, "
                        "no CPU address reaches it"))

    sw = 14
    for fill, stroke, text in legend:
        d.rect(GRID_LEFT, d.y, sw, sw, fill, stroke, stroke_width=0.8)
        d.text(GRID_LEFT + sw + 8, d.y + sw - 3, text, size=11)
        d.y += sw + 6

    # ---- counts line ---------------------------------------------------
    total_rom = counts["canonical"] + counts["mirror"]
    d.y += 10
    d.wrapped_block(
        [
            f"512 half-bank cells (256 banks × 2 halves): {total_rom} decode to "
            f"cartridge ROM ({counts['canonical']} canonical + {counts['mirror']} mirror), "
            f"{counts['wram']} WRAM, {counts['unmapped']} system-area"
            + (f", {counts['hole']} unreachable-hole." if counts["hole"] else "."),
        ],
        GRID_LEFT, size=11, leading=14, fill=MUTED_COLOR,
    )

    # ---- canonical windows table ----------------------------------------
    d.y += 12
    d.text(GRID_LEFT, d.y, "canonical windows", size=12, weight="bold")
    window_lines = []
    for w in cm.windows():
        dev_idx, _off = cm.physical(w.file_start)
        window_lines.append(f"{w}  (ROM {dev_idx + 1})")
    d.line_block(window_lines, GRID_LEFT, size=10.5, leading=14, fill=TEXT_COLOR)

    # ---- non-monotonic seam callouts (derived: bank number drops while the
    #      file offset keeps climbing between consecutive canonical windows) --
    windows = cm.windows()
    seam_lines = []
    for a, b in zip(windows, windows[1:]):
        if b.bank_lo < a.bank_lo:
            seam_lines.append(
                f"seam at file ${a.file_end:06X}: CPU bank drops ${a.bank_hi:02X}→"
                f"${b.bank_lo:02X} while the file offset keeps increasing — a segment "
                "cursor must reload the bank byte here, never increment across it."
            )
    if seam_lines:
        d.y += 12
        d.text(GRID_LEFT, d.y, "file→CPU seam(s)", size=12, weight="bold")
        d.wrapped_block(seam_lines, GRID_LEFT, size=10.5, leading=14, fill=MUTED_COLOR)

    if len(cm.devices) > 1:
        d.y += 12
        d.text(GRID_LEFT, d.y, "device split", size=12, weight="bold")
        d.wrapped_block(
            [f"{len(cm.devices)} physical mask ROMs: " + ", ".join(
                f"ROM {dev.index + 1} = {dev.label} @ file "
                f"${dev.file_start:06X}–${dev.file_end - 1:06X}" for dev in cm.devices
            )],
            GRID_LEFT, size=10.5, leading=14, fill=MUTED_COLOR,
        )

    height = int(d.y + 20)
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS_W} {height}" '
        f'width="100%" height="auto" role="img" '
        f'aria-label="{escape(label)} CPU bank decode map">'
        f'<rect x="0" y="0" width="{CANVAS_W}" height="{height}" fill="{BG_COLOR}"/>'
        + "".join(d.parts)
        + "</svg>"
    )

    stats = {
        "total": total_rom,
        "canonical": counts["canonical"],
        "mirror": counts["mirror"],
        "wram": counts["wram"],
        "unmapped": counts["unmapped"],
        "hole_cells": counts["hole"],
        "hole_bytes": len(hole_banks) * CartMap.CELL,
    }
    return svg, stats


# --------------------------------------------------------------------------
# Regression lock: the exact per-config counts named in the plan (6 MiB:
# 380 total decode cells / 192 canonical / 188 mirror) plus the two other
# milestone configs, cross-checked two independent ways -- against the
# hardcoded expectation below, and against `CartMap.holes()` directly, so a
# future `snes_cartmap.py` change that silently shifts the decode can't pass
# quietly.
# --------------------------------------------------------------------------
CONFIGS = (
    ("hirom", 0x400000, "HiROM 4 MiB (32 Mbit)"),
    ("exhirom", 0x600000, "ExHiROM 6 MiB (48 Mbit)"),
    ("exhirom", 0x800000, "ExHiROM 8 MiB (64 Mbit)"),
)

EXPECTED = {
    ("hirom", 0x400000): {"total": 380, "canonical": 128, "mirror": 252, "hole_bytes": 0},
    ("exhirom", 0x600000): {"total": 380, "canonical": 192, "mirror": 188, "hole_bytes": 0},
    ("exhirom", 0x800000): {"total": 380, "canonical": 254, "mirror": 126, "hole_bytes": 65536},
}


def selftest() -> None:
    for mapping, size, label in CONFIGS:
        svg, stats = build_svg(mapping, size, label)
        want = EXPECTED[(mapping, size)]
        for key, expect in want.items():
            got = stats[key]
            if got != expect:
                raise AssertionError(
                    f"{label}: stats[{key!r}] = {got}, expected {expect} "
                    f"(full stats: {stats})"
                )
        # Cross-check the hole byte count against the model's own `holes()`,
        # independent of how this file derived `hole_banks`.
        cm = CartMap(mapping, size)
        model_hole_bytes = sum(end - start for start, end in cm.holes())
        if model_hole_bytes != stats["hole_bytes"]:
            raise AssertionError(
                f"{label}: hole bytes derived from windows() ({stats['hole_bytes']}) "
                f"disagree with CartMap.holes() ({model_hole_bytes})"
            )
        if not svg.startswith("<svg") or not svg.endswith("</svg>"):
            raise AssertionError(f"{label}: malformed SVG output")
        print(f"OK  {label:28s} total={stats['total']:3d} canonical={stats['canonical']:3d} "
              f"mirror={stats['mirror']:3d} hole_bytes={stats['hole_bytes']}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="snes-cartmap-viz.py",
        description="Render the SNES cartridge decode map as an inline SVG, "
                     "derived entirely from tools/snes_cartmap.py.",
    )
    ap.add_argument("--mapping", choices=("lorom", "hirom", "exhirom"))
    ap.add_argument("--size", type=parse_size, help="e.g. 6M, 48Mbit, 0x600000")
    ap.add_argument("--label", help="override the title (default: derived from mapping/size)")
    ap.add_argument("--out", help="write SVG here instead of stdout")
    ap.add_argument("--selftest", action="store_true",
                     help="build all three milestone configs and assert their decode-cell "
                          "counts match the plan's numbers; prints a report, writes nothing")
    args = ap.parse_args(argv[1:])

    if args.selftest:
        selftest()
        return 0

    if not args.mapping or args.size is None:
        ap.error("--mapping and --size are required (or pass --selftest)")

    label = args.label or f"{args.mapping.upper()} {args.size // (1 << 20)} MiB"
    svg, _stats = build_svg(args.mapping, args.size, label)
    if args.out:
        Path(args.out).write_text(svg)
    else:
        print(svg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
