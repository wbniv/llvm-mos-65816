#!/usr/bin/env python3
"""Standalone PSNR check: decode a tiles+palette corpus back to RGB using the
same BGR555->RGB gamma-corrected palette math as
tools/snes-video-screenshot-check.py's render_frame (but at native 80x56, no
resize), then compare every byte against the source RGB24 corpus.

Read-only analysis -- no decoder/codec changes. Written to confirm the
quality-cost side of the Bayer-vs-Floyd dither trade in
docs/plans/2026-08-03-interframe-crossover.md (P2 confirming run, 2026-08-04):
that plan cites PSNR numbers for several corpora but had no in-repo tool to
reproduce them, so this exists to make the next corpus's number a rerun
instead of a fresh ad hoc script.

Usage:
    tools/snes-video-psnr-check.py SOURCE.rgb TILES.tiles PALETTE.pal [FRAMES]
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

FRAME_SIZE = 4480
WIDTH, HEIGHT = 80, 56


def bsnes_channel(value: int) -> int:
    expanded = ((value << 3) | (value >> 2)) * 257
    corrected = (32767 * math.pow(expanded / 32767, 1.2)
                 if expanded <= 32767 else expanded)
    return min(int(corrected), 65535) >> 8


def palette_rgb(palette: bytes) -> list[tuple[int, int, int]]:
    colors = []
    for offset in range(0, 448, 2):
        word = palette[offset] | palette[offset + 1] << 8
        colors.append((bsnes_channel(word & 31), bsnes_channel((word >> 5) & 31),
                        bsnes_channel((word >> 10) & 31)))
    return colors


def decode_frame(tiles: bytes, index: int, pal_rgb: list[tuple[int, int, int]]) -> bytes:
    frame = tiles[index * FRAME_SIZE:(index + 1) * FRAME_SIZE]
    raster = bytearray(WIDTH * HEIGHT)
    for tile_y in range(7):
        for tile_x in range(10):
            source = (tile_y * 10 + tile_x) * 64
            for row in range(8):
                destination = (tile_y * 8 + row) * WIDTH + tile_x * 8
                raster[destination:destination + 8] = frame[source + row * 8:source + row * 8 + 8]
    out = bytearray(WIDTH * HEIGHT * 3)
    for i, idx in enumerate(raster):
        out[i * 3:i * 3 + 3] = bytes(pal_rgb[idx])
    return bytes(out)


def main() -> int:
    if len(sys.argv) < 4 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0 if sys.argv[1:2] == ["-h"] or sys.argv[1:2] == ["--help"] else 2
    rgb_path, tiles_path, pal_path = sys.argv[1], sys.argv[2], sys.argv[3]
    n_frames = int(sys.argv[4]) if len(sys.argv) > 4 else None

    rgb = Path(rgb_path).read_bytes()
    tiles = Path(tiles_path).read_bytes()
    palette = Path(pal_path).read_bytes()
    if len(palette) != 448:
        print(f"FATAL: palette must be 448 bytes, got {len(palette)}", file=sys.stderr)
        return 1
    pal_rgb = palette_rgb(palette)

    frame_bytes = WIDTH * HEIGHT * 3
    total_frames = len(rgb) // frame_bytes
    if n_frames:
        total_frames = min(total_frames, n_frames)

    squared_error = 0
    sample_count = 0
    for i in range(total_frames):
        source = rgb[i * frame_bytes:(i + 1) * frame_bytes]
        decoded = decode_frame(tiles, i, pal_rgb)
        for a, b in zip(source, decoded):
            diff = a - b
            squared_error += diff * diff
            sample_count += 1

    mse = squared_error / sample_count
    psnr = 999.0 if mse == 0 else 10 * math.log10((255 * 255) / mse)
    print(f"frames={total_frames} mse={mse:.4f} psnr={psnr:.2f} dB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
