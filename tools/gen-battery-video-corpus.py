#!/usr/bin/env python3
"""Emit a deterministic synthetic RGB24 corpus for the example battery.

The two video demos (`examples/snes/apollo-reel.c`,
`examples/snes/snes-video-codec-bench.c`) include a *generated* asset header, so
they cannot compile until an asset corpus exists. Their behavioural gates
(`dev/apollo-reel.sh`, `dev/snes-video-codec-bench.sh`) bake that header from a
recorded real-camera corpus whose SHA-256 is asserted there — that is where
codec fidelity is judged.

The example battery in `dev/build.sh` judges something narrower: that every demo
still COMPILES and LINKS. This corpus serves that purpose — synthetic, seeded,
dependency-free (no ffmpeg, no source video), identical on every machine and on
every run, so the battery's ROMs are reproducible and a build break in either
demo surfaces at `task package` time instead of hiding behind a missing header.

Output format is the codec corpus format `tools/snes-video-pack.py --rgb24`
consumes: concatenated 80x56 row-major RGB24 frames (13,440 bytes per frame).

The content is a drifting plasma plus a sweeping bright bar: smooth gradients
give the palette quantizer a real spread of colours to fit, and the moving bar
gives the inter-frame coder a genuine delta to encode, so neither the palette
fit nor the XOR/packbits paths degenerate to a trivial all-zero case.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

WIDTH = 80
HEIGHT = 56
FRAME_BYTES = WIDTH * HEIGHT * 3


def frame(index: int) -> bytearray:
    """One 80x56 RGB24 frame: drifting plasma + a sweeping bar."""
    out = bytearray(FRAME_BYTES)
    phase = index * 0.37
    bar = (index * 7) % WIDTH
    pos = 0
    for y in range(HEIGHT):
        fy = y * 0.19
        for x in range(WIDTH):
            fx = x * 0.13
            v = (
                math.sin(fx + phase)
                + math.sin(fy - phase * 0.7)
                + math.sin((fx + fy) * 0.5 + phase * 1.3)
            )
            base = int((v + 3.0) * 42.0)
            r = base
            g = (base * 3) // 4
            b = 255 - base
            # A hard-edged sweeping bar: a real, localized inter-frame delta.
            if abs(x - bar) <= 2:
                r, g, b = 255, 255, 220
            out[pos] = max(0, min(255, r))
            out[pos + 1] = max(0, min(255, g))
            out[pos + 2] = max(0, min(255, b))
            pos += 3
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Emit a deterministic synthetic 80x56 RGB24 corpus for the example battery."
    )
    ap.add_argument("--frames", type=int, default=12, help="frame count (default: 12)")
    ap.add_argument("output", type=Path, help="output .rgb path")
    args = ap.parse_args(argv)

    if args.frames < 1:
        ap.error("--frames must be >= 1")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as fh:
        for i in range(args.frames):
            fh.write(frame(i))
    print(
        f"wrote {args.output}: {args.frames} frames, {args.frames * FRAME_BYTES} bytes"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
