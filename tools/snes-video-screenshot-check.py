#!/usr/bin/env python3
"""Compare an emulator capture with the corresponding host-rendered video frame."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops

FRAME_SIZE = 4480


def render_frame(tiles: bytes, palette: bytes, index: int, height: int,
                 matrix_d: int | None = None) -> Image.Image:
    frame = tiles[index * FRAME_SIZE:(index + 1) * FRAME_SIZE]
    if len(frame) != FRAME_SIZE:
        raise ValueError(f"frame {index} is outside the tile corpus")
    raster = bytearray(80 * 56)
    for tile_y in range(7):
        for tile_x in range(10):
            source = (tile_y * 10 + tile_x) * 64
            for row in range(8):
                destination = (tile_y * 8 + row) * 80 + tile_x * 8
                raster[destination:destination + 8] = frame[source + row * 8:source + row * 8 + 8]
    colors: list[int] = []
    for offset in range(0, 448, 2):
        word = palette[offset] | palette[offset + 1] << 8
        colors.extend(((word & 31) << 3, ((word >> 5) & 31) << 3, ((word >> 10) & 31) << 3))
    image = Image.frombytes("P", (80, 56), bytes(raster))
    image.putpalette(colors + [0] * (768 - len(colors)))
    image = image.convert("RGB")
    if matrix_d is None:
        return image.resize((256, height), Image.Resampling.NEAREST)
    # Match the integer sampling performed by Mode 7.  The vertical origin is
    # one source pixel above scanline zero for this dashboard split; Pillow's
    # affine pixel-centre convention is close, but differs at scaling edges.
    source = image.load()
    scaled = Image.new("RGB", (256, height))
    destination = scaled.load()
    for y in range(height):
        source_y = max(0, min(55, (matrix_d * y - 256) >> 8))
        for x in range(256):
            destination[x, y] = source[min(79, (80 * x) >> 8), source_y]
    return scaled


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("tiles", type=Path)
    parser.add_argument("palette", type=Path)
    parser.add_argument("--frame", type=int, required=True)
    parser.add_argument("--video-height", type=int, default=224)
    parser.add_argument("--matrix-d", type=int)
    parser.add_argument("--minimum-exact", type=float, default=0.90)
    parser.add_argument("--maximum-mae", type=float, default=2.5)
    args = parser.parse_args()
    palette = args.palette.read_bytes()
    if len(palette) != 448:
        parser.error(f"palette must be 448 bytes, got {len(palette)}")
    actual = Image.open(args.screenshot).convert("RGB")
    if actual.size != (256, 224):
        parser.error(f"screenshot must be 256x224, got {actual.size}")
    if not 1 <= args.video_height <= 224:
        parser.error("--video-height must be between 1 and 224")
    actual = actual.crop((0, 0, 256, args.video_height))
    expected = render_frame(args.tiles.read_bytes(), palette, args.frame, args.video_height,
                            args.matrix_d)
    difference = ImageChops.difference(actual, expected)
    histogram = difference.histogram()
    samples = actual.width * actual.height * 3
    absolute = sum((bucket % 256) * count for bucket, count in enumerate(histogram))
    mae = absolute / samples
    exact = sum(1 for left, right in
                zip(actual.get_flattened_data(), expected.get_flattened_data()) if left == right)
    exact_ratio = exact / (actual.width * actual.height)
    passed = exact_ratio >= args.minimum_exact and mae <= args.maximum_mae
    print(f"FIDELITY: {'PASS' if passed else 'FAIL'} frame={args.frame} "
          f"exact={exact_ratio:.4%} mae={mae:.4f}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
