#!/usr/bin/env python3
"""Summarize target-side SVX2 stage/decode/present PPU-dot profiles."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


DOTS_PER_FRAME = 262 * 341
QUANTUM_DOTS = 1024
RECORD = struct.Struct("BBB")


def percentile(values: list[int], percent: int) -> int:
    ordered = sorted(values)
    return ordered[((len(ordered) - 1) * percent + 99) // 100]


def stats(values: list[int]) -> dict[str, float | int]:
    return {
        "min_dots": min(values),
        "p50_dots": percentile(values, 50),
        "p95_dots": percentile(values, 95),
        "p99_dots": percentile(values, 99),
        "max_dots": max(values),
        "max_frames": round(max(values) / DOTS_PER_FRAME, 4),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=Path)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    data = args.profile.read_bytes()
    expected = args.frames * RECORD.size
    if len(data) != expected:
        parser.error(f"expected {expected} bytes for {args.frames} frames, got {len(data)}")
    quantized = [RECORD.unpack_from(data, i * RECORD.size) for i in range(args.frames)]
    records = [tuple(value * QUANTUM_DOTS for value in record) for record in quantized]
    if any(not stage or not decode or not present for stage, decode, present in records):
        missing = [i for i, record in enumerate(records) if 0 in record]
        parser.error(f"incomplete target profile; missing phases for frames {missing[:12]}")
    result = {
        "frames": args.frames,
        "dots_per_ntsc_frame": DOTS_PER_FRAME,
        "measurement_quantum_dots": QUANTUM_DOTS,
        "stage": stats([r[0] for r in records]),
        "decode": stats([r[1] for r in records]),
        "present": stats([r[2] for r in records]),
        "combined": stats([sum(r) for r in records]),
        "worst_frame": max(range(args.frames), key=lambda i: sum(records[i])),
    }
    rendered = json.dumps(result, indent=2)
    print(rendered)
    if args.json:
        args.json.write_text(rendered + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
