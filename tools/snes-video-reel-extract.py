#!/usr/bin/env python3
"""Recover raw tile frames (and the shipping palette) from a packed SVX2 reel.

The reel generator (tools/snes-video-reel-assets.py) consumes concatenated
4,480-byte tile-major frames plus a 448-byte BGR555 palette.  Those inputs are
untracked /tmp intermediates with no in-tree recipe; the checked-in
examples/snes/snes-video-reel-assets.h + assets/snes/video/svx2-full-reel.bin
pair is the only durable record of the shipped frames.  This tool inverts the
generator for a consecutive frame window so a small fixture reel (the LoROM
first cartridge of docs/plans/2026-07-31-svx2-animated-video-cartridge.md) can
be regenerated from tracked assets alone.

Decoding starts at the nearest keyframe at or before --start, so any window is
reachable; every decoded frame is checked against reel_frame_crcs[] so a
header/stream mismatch is a hard error rather than garbage tiles.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from snes_video_codec import FLAG_KEYFRAME, FRAME_SIZE, XOR_HEADER, crc16, decode_xor_frame

PALETTE_BYTES = 448


def _array(header: str, name: str, suffix: str) -> list[int]:
    match = re.search(rf"\b{name}\[\d*\]\s*=\s*\{{(.*?)\}};", header, re.S)
    if not match:
        raise SystemExit(f"FATAL: {name}[] not found in header")
    body = re.sub(r"//.*", "", match.group(1))
    values = re.findall(rf"(0x[0-9a-fA-F]+|\d+){suffix}\b", body)
    if not values:
        raise SystemExit(f"FATAL: {name}[] is empty")
    return [int(value, 0) for value in values]


def _define(header: str, name: str) -> int | None:
    match = re.search(rf"^#define\s+{name}\s+(0x[0-9a-fA-F]+|\d+)u?l?\s*$", header, re.M)
    return int(match.group(1), 0) if match else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("header", type=Path, help="generated snes-video-reel-assets.h")
    parser.add_argument("stream", type=Path, help="packed stream written by --stream-output")
    parser.add_argument("--start", type=int, default=0, help="first frame to extract")
    parser.add_argument("--frames", type=int, default=4, help="number of consecutive frames")
    parser.add_argument("--tiles-output", type=Path, required=True,
                        help="write --frames × 4480 tile-major bytes here")
    parser.add_argument("--palette-output", type=Path,
                        help="write the header's 448-byte reel_palette here")
    args = parser.parse_args()

    header = args.header.read_text()
    stream = args.stream.read_bytes()
    if _define(header, "VIDEO_REEL_PACKED_FAR") is None:
        parser.error("header is not a --packed-far reel (no reel_packet_offsets stream)")
    frame_count = _define(header, "VIDEO_REEL_FRAME_COUNT")
    offsets = _array(header, "reel_packet_offsets", "ul")
    crcs = _array(header, "reel_frame_crcs", "u")
    palette = bytes(_array(header, "reel_palette", ""))
    if frame_count is None or len(offsets) != frame_count + 1 or len(crcs) != frame_count:
        parser.error(f"header inconsistent: frames={frame_count} offsets={len(offsets)} crcs={len(crcs)}")
    if len(palette) != PALETTE_BYTES:
        parser.error(f"reel_palette is {len(palette)} bytes, expected {PALETTE_BYTES}")
    if any(b > a for a, b in zip(offsets[1:], offsets)):
        parser.error("reel_packet_offsets must be non-decreasing")
    if offsets[-1] > len(stream):
        parser.error(f"stream is {len(stream)} bytes but offsets reach {offsets[-1]}")
    if args.frames < 1 or args.start < 0 or args.start + args.frames > frame_count:
        parser.error(f"--start/--frames must select frames within 0..{frame_count - 1}")

    def packet(index: int) -> bytes:
        return stream[offsets[index]:offsets[index + 1]]

    def is_keyframe(index: int) -> bool:
        data = packet(index)
        return len(data) >= XOR_HEADER.size and bool(data[4] & FLAG_KEYFRAME)

    origin = args.start
    while origin > 0 and not is_keyframe(origin):
        origin -= 1
    if not is_keyframe(origin):
        parser.error(f"no keyframe at or before frame {args.start}")

    previous: bytes | None = None
    frames: list[bytes] = []
    for index in range(origin, args.start + args.frames):
        frame = decode_xor_frame(packet(index), previous)
        if crc16(frame) != crcs[index]:
            raise SystemExit(f"FATAL: frame {index} decodes to CRC 0x{crc16(frame):04x}, "
                             f"header says 0x{crcs[index]:04x} — header/stream pair mismatch")
        if index >= args.start:
            frames.append(frame)
        previous = frame

    args.tiles_output.write_bytes(b"".join(frames))
    if args.palette_output:
        args.palette_output.write_bytes(palette)
    print(f"extracted frames {args.start}..{args.start + args.frames - 1} "
          f"(decoded from keyframe {origin}) -> {args.tiles_output} "
          f"({len(frames) * FRAME_SIZE} bytes)"
          + (f"; palette -> {args.palette_output}" if args.palette_output else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
