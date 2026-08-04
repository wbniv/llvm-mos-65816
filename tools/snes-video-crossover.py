#!/usr/bin/env python3
"""Per-frame interframe/intraframe crossover measurement for SVX2 corpora.

Answers the P0/P1 questions of docs/plans/2026-08-03-interframe-crossover.md:

  P0  For every frame of a tile corpus, what does the SVX2 *delta* packet cost
      and what does the SVX2 *keyframe* packet cost?  The recorded numbers in
      the codec benchmark are whole-corpus aggregates, which hide the
      distribution: a 14-point corpus-level gap could be a few shot cuts or it
      could be every single frame.

  P1  Size and decode time trade in opposite directions.  A keyframe is often
      the *smaller* packet on hard content but costs 1.12 VBlanks against a
      delta's 0.89 (slow ROM) / 0.80 (FastROM), so under the shipped
      non-pipelined schedule it occupies a two-VBlank slot.  "Pick the smaller
      per frame" is therefore wrong; the real problem is minimise bytes subject
      to holding cadence.  This tool evaluates that constrained chooser.

A property of SVX2 that makes the whole analysis tractable: the codec is
lossless, so the decoded previous frame always equals the source previous frame
no matter which packet kind was emitted for it.  Per-frame packet costs are
therefore *independent* of every other frame's choice -- the chooser is a
top-m selection, not a dynamic program over reconstruction state.  The script
asserts this rather than assuming it (--verify-independence).

Usage:
    tools/snes-video-crossover.py CORPUS.tiles [--label NAME] [--json OUT.json]
                                 [--fixed-k 15,30,60,120]
                                 [--budgets 0,0.008333,0.01,0.05,0.10,1.0]
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics
import sys

from snes_video_codec import FRAME_SIZE, decode_xor_frame, encode_xor_frame

# Measured target costs, in VBlanks per packet.
# Keyframe: 537 staged-specialization decodes per 600 VBlanks
#   (docs/plans/2026-08-01-svx2-60fps-ring-refill.md, Option C).
# Delta: hardest stream slice, 674 frames per 600 VBlanks slow ROM /
#   754 FastROM (docs/plans/2026-08-02-apollo-daylight-video-rom.md).
KEYFRAME_VBLANKS = 600 / 537
DELTA_VBLANKS_SLOWROM = 600 / 674
DELTA_VBLANKS_FASTROM = 600 / 754

# The shipped schedule decodes one packet per interval and does not split a
# decode across intervals, so a packet costing more than one VBlank consumes
# two slots.  Both delta figures are below 1.0; the keyframe figure is above.
CONTAINER_BYTES = 2  # length prefix the stream packer adds around each packet


def slots(vblanks: float) -> int:
    """Whole VBlank slots a packet occupies under the non-pipelined schedule."""
    import math
    return max(1, math.ceil(vblanks - 1e-9))


def frames_from_file(path: Path) -> list[bytes]:
    data = path.read_bytes()
    if not data or len(data) % FRAME_SIZE:
        raise ValueError(f"{path}: size must be a non-zero multiple of {FRAME_SIZE}")
    return [data[i:i + FRAME_SIZE] for i in range(0, len(data), FRAME_SIZE)]


def measure(frames: list[bytes], verify_independence: bool = True) -> dict:
    """Per-frame delta and keyframe packet sizes, including container overhead."""
    delta = [None] * len(frames)
    key = [None] * len(frames)
    for index, frame in enumerate(frames):
        packet = encode_xor_frame(frame, None, keyframe=True)
        if decode_xor_frame(packet, None) != frame:
            raise RuntimeError(f"frame {index}: keyframe round trip failed")
        key[index] = CONTAINER_BYTES + len(packet)
        if index:
            previous = frames[index - 1]
            packet = encode_xor_frame(frame, previous, keyframe=False)
            decoded = decode_xor_frame(packet, previous)
            if decoded != frame:
                raise RuntimeError(f"frame {index}: delta round trip failed")
            delta[index] = CONTAINER_BYTES + len(packet)
    # Independence, established rather than assumed: the loop above decoded
    # *both* packet kinds for every frame and checked each against the source
    # bytes.  Both therefore reconstruct byte-identical output, so whichever
    # kind frame i-1 is emitted as, frame i's delta is coded against the same
    # previous bytes and costs the same.  No cross-frame coupling exists, and
    # the chooser below is a top-m selection rather than a dynamic program.
    return {"delta": delta, "key": key}


def fixed_k_bytes(delta: list, key: list, interval: int) -> int:
    return sum(key[i] if i % interval == 0 else delta[i] for i in range(len(key)))


def chooser_bytes(delta: list, key: list, max_keyframe_fraction: float,
                  forced: set[int]) -> tuple[int, int]:
    """Minimum bytes with at most `fraction`*N keyframes, `forced` always keys.

    Because per-frame costs are independent, the optimum is: take every forced
    keyframe, then spend the remaining keyframe budget on the frames with the
    largest positive saving (delta - key).  Returns (bytes, keyframe count).
    """
    total_frames = len(key)
    budget = int(max_keyframe_fraction * total_frames)
    chosen = set(forced)
    savings = sorted(
        ((delta[i] - key[i], i) for i in range(total_frames)
         if i not in chosen and delta[i] is not None and delta[i] > key[i]),
        reverse=True)
    for _, index in savings:
        if len(chosen) >= budget:
            break
        chosen.add(index)
    total = sum(key[i] if i in chosen else delta[i] for i in range(total_frames))
    return total, len(chosen)


def windowed_placement_bytes(delta: list, key: list, interval: int) -> tuple[int, int]:
    """Same keyframe *count* as fixed-K, but each window's keyframe is placed on
    the frame where a keyframe saves the most (or costs the least).

    Cadence cost is identical to fixed-K -- the chooser is free in VBlanks.  The
    price is seek granularity: the gap between consecutive keyframes ranges over
    1..2*interval-1 frames instead of being exactly `interval`.
    """
    total_frames = len(key)
    chosen = {0}
    for start in range(interval, total_frames, interval):
        window = range(start, min(start + interval, total_frames))
        best = max(window, key=lambda i: delta[i] - key[i])
        chosen.add(best)
    total = sum(key[i] if i in chosen else delta[i] for i in range(total_frames))
    worst_gap = 0
    ordered = sorted(chosen)
    for a, b in zip(ordered, ordered[1:]):
        worst_gap = max(worst_gap, b - a)
    return total, worst_gap


def effective_fps(total_frames: int, keyframes: int, base: float = 60.0) -> float:
    """Presented fps when each keyframe consumes an extra VBlank slot."""
    key_slots = slots(KEYFRAME_VBLANKS)
    delta_slots = slots(DELTA_VBLANKS_SLOWROM)
    vblanks = keyframes * key_slots + (total_frames - keyframes) * delta_slots
    return base * total_frames / vblanks


def report(label: str, path: Path, frames: list[bytes], intervals: list[int],
           budgets: list[float]) -> dict:
    measured = measure(frames)
    delta, key = measured["delta"], measured["key"]
    total_frames = len(frames)
    raw = total_frames * FRAME_SIZE

    codeable = [i for i in range(1, total_frames)]
    key_wins = [i for i in codeable if key[i] < delta[i]]
    margins = [delta[i] - key[i] for i in codeable]
    positive = sorted((m for m in margins if m > 0), reverse=True)

    print(f"== {label} ==")
    print(f"corpus          {path}")
    print(f"sha256          {hashlib.sha256(path.read_bytes()).hexdigest()}")
    print(f"frames          {total_frames}   raw {raw:,} B")
    print()
    print("-- P0: per-frame crossover (frames 1..N-1; frame 0 is forced key) --")
    print(f"keyframe smaller than delta   {len(key_wins):>6} / {len(codeable)} "
          f"= {100.0 * len(key_wins) / len(codeable):.2f}%")
    print(f"delta   - key   mean          {statistics.mean(margins):>10.1f} B")
    print(f"delta   - key   median        {statistics.median(margins):>10.1f} B")
    for q, name in ((0.05, "p05"), (0.25, "p25"), (0.75, "p75"), (0.95, "p95")):
        ordered = sorted(margins)
        print(f"delta   - key   {name}           "
              f"{ordered[min(len(ordered) - 1, int(q * len(ordered)))]:>10.1f} B")
    print(f"delta   - key   min / max     {min(margins):>10,} / {max(margins):,} B")
    if positive:
        head = max(1, len(codeable) // 100)
        print(f"total available saving        {sum(positive):>10,} B "
              f"({100.0 * sum(positive) / raw:.2f}% of raw)")
        print(f"  concentrated? top 1% of frames ({head}) carry "
              f"{100.0 * sum(positive[:head]) / sum(positive):.1f}% of it")
        runs, run = [], 0
        keyset = set(key_wins)
        for i in codeable:
            if i in keyset:
                run += 1
            elif run:
                runs.append(run)
                run = 0
        if run:
            runs.append(run)
        if runs:
            print(f"  contiguity: {len(runs)} runs of keyframe-favouring frames, "
                  f"longest {max(runs)}, mean {statistics.mean(runs):.1f}")
    else:
        print("total available saving                 0 B (delta wins everywhere)")
    print()

    print("-- reconciliation: fixed-K totals (must match the benchmark doc) --")
    fixed = {}
    for interval in intervals:
        total = fixed_k_bytes(delta, key, interval)
        fixed[interval] = total
        print(f"K={interval:<4} {total:>10,} B  ({100.0 * total / raw:5.2f}% of raw)  "
              f"keyframes {len(range(0, total_frames, interval)):>4}  "
              f"effective {effective_fps(total_frames, len(range(0, total_frames, interval))):.2f} fps")
    print()

    print("-- P1: minimise bytes subject to holding cadence --")
    print("budget phi   max keys   bytes        %raw    saving vs K=120   effective fps")
    ship = fixed.get(120, fixed[max(intervals)])
    rows = []
    for phi in budgets:
        total, keys = chooser_bytes(delta, key, phi, forced={0})
        fps = effective_fps(total_frames, keys)
        rows.append({"phi": phi, "keyframes": keys, "bytes": total, "fps": fps})
        print(f"{phi * 100:8.3f}%  {int(phi * total_frames):>8}   {total:>10,}  "
              f"{100.0 * total / raw:6.2f}%  {ship - total:>12,} B     {fps:.2f}")
    print()

    print("-- P1b: free chooser -- same keyframe count as fixed-K, best placement --")
    print("K      bytes        %raw    saving vs fixed-K   worst seek gap (frames)")
    placement = []
    for interval in intervals:
        total, gap = windowed_placement_bytes(delta, key, interval)
        placement.append({"interval": interval, "bytes": total, "worst_gap": gap})
        print(f"{interval:<5}  {total:>10,}  {100.0 * total / raw:6.2f}%  "
              f"{fixed[interval] - total:>17,} B   {gap:>6}")
    print()

    return {
        "label": label, "path": str(path), "frames": total_frames, "raw_bytes": raw,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "keyframe_wins": len(key_wins), "codeable": len(codeable),
        "keyframe_win_fraction": len(key_wins) / len(codeable),
        "margin_mean": statistics.mean(margins),
        "margin_median": statistics.median(margins),
        "margin_min": min(margins), "margin_max": max(margins),
        "available_saving": sum(positive),
        "fixed_k": fixed, "chooser": rows, "placement": placement,
        "per_frame_delta": delta, "per_frame_key": key,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("corpus", type=Path, help="tile-major 4480-byte frame corpus")
    parser.add_argument("--label", default=None, help="name for the report header")
    parser.add_argument("--json", type=Path, help="write the full per-frame record here")
    parser.add_argument("--fixed-k", default="15,30,60,120",
                        help="keyframe intervals to reconcile against (default: 15,30,60,120)")
    parser.add_argument("--budgets", default="0,0.008333,0.01,0.05,0.10,1.0",
                        help="keyframe fraction budgets for the constrained chooser")
    args = parser.parse_args()

    intervals = [int(v) for v in args.fixed_k.split(",")]
    budgets = [float(v) for v in args.budgets.split(",")]
    frames = frames_from_file(args.corpus)
    record = report(args.label or args.corpus.stem, args.corpus, frames, intervals, budgets)
    if args.json:
        args.json.write_text(json.dumps(record, indent=1))
        print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
