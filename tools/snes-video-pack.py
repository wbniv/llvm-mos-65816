#!/usr/bin/env python3
"""Pack, verify, or benchmark tile-major 80x56 indexed SNES video."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

from snes_video_codec import (BLOCK_COUNT, FRAME_SIZE, OP_COPY, OP_RAW, OP_SAME, OP_SOLID,
                              OP_TWO_COLOR, OP_XOR_PACKBITS, decode_frame, encode_frame,
                              decode_xor_frame, encode_xor_frame, lzss_decode, lzss_encode, scanline_packbits_decode,
                              scanline_packbits_encode)


def frames_from_file(path: Path) -> list[bytes]:
    data = path.read_bytes()
    if not data or len(data) % FRAME_SIZE:
        raise ValueError(f"{path}: size must be a non-zero multiple of {FRAME_SIZE}")
    return [data[i:i + FRAME_SIZE] for i in range(0, len(data), FRAME_SIZE)]


def quantize_rgb24(path: Path, dither: str = "floyd") -> tuple[list[bytes], bytes]:
    from PIL import Image

    raster_size = 80 * 56 * 3
    data = path.read_bytes()
    if not data or len(data) % raster_size:
        raise ValueError(f"{path}: RGB24 size must be a non-zero multiple of {raster_size}")
    rgb_frames = [data[i:i + raster_size] for i in range(0, len(data), raster_size)]
    atlas = Image.frombytes("RGB", (80, 56 * len(rgb_frames)), b"".join(rgb_frames))
    learned = atlas.quantize(colors=223, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette_rgb = learned.getpalette()[:223 * 3]
    palette_image = Image.new("P", (1, 1))
    palette_image.putpalette(palette_rgb + [0] * (768 - len(palette_rgb)))
    bayer8 = (
        (0, 48, 12, 60, 3, 51, 15, 63), (32, 16, 44, 28, 35, 19, 47, 31),
        (8, 56, 4, 52, 11, 59, 7, 55), (40, 24, 36, 20, 43, 27, 39, 23),
        (2, 50, 14, 62, 1, 49, 13, 61), (34, 18, 46, 30, 33, 17, 45, 29),
        (10, 58, 6, 54, 9, 57, 5, 53), (42, 26, 38, 22, 41, 25, 37, 21),
    )
    tiled_frames = []
    for rgb in rgb_frames:
        image = Image.frombytes("RGB", (80, 56), rgb)
        if dither == "bayer":
            pixels = bytearray(rgb)
            for y in range(56):
                for x in range(80):
                    adjustment = (bayer8[y & 7][x & 7] - 32) // 4  # deterministic -8..+7
                    offset = (y * 80 + x) * 3
                    for channel in range(3):
                        pixels[offset + channel] = max(0, min(255, pixels[offset + channel] + adjustment))
            image = Image.frombytes("RGB", (80, 56), bytes(pixels))
            pillow_dither = Image.Dither.NONE
        elif dither == "none":
            pillow_dither = Image.Dither.NONE
        elif dither == "floyd":
            pillow_dither = Image.Dither.FLOYDSTEINBERG
        else:
            raise ValueError(f"unknown dither mode: {dither}")
        indexed = image.quantize(palette=palette_image, dither=pillow_dither)
        raster = bytes(value + 1 for value in indexed.tobytes())
        tiled = bytearray()
        for tile_y in range(7):
            for tile_x in range(10):
                for y in range(8):
                    start = (tile_y * 8 + y) * 80 + tile_x * 8
                    tiled.extend(raster[start:start + 8])
        tiled_frames.append(bytes(tiled))
    bgr555 = bytearray((0, 0))  # index 0 is reserved/transparent
    for offset in range(0, len(palette_rgb), 3):
        red, green, blue = palette_rgb[offset:offset + 3]
        word = (red >> 3) | ((green >> 3) << 5) | ((blue >> 3) << 10)
        bgr555.extend(word.to_bytes(2, "little"))
    return tiled_frames, bytes(bgr555)


VARIANTS = {
    "raw-blocks": frozenset((OP_RAW,)),
    "changed-blocks": frozenset((OP_SAME, OP_RAW)),
    "motion-copy": frozenset((OP_SAME, OP_COPY, OP_RAW)),
    "xor-packbits": frozenset((OP_SAME, OP_XOR_PACKBITS, OP_RAW)),
    "full-svc1": frozenset((OP_SAME, OP_COPY, OP_SOLID, OP_TWO_COLOR, OP_XOR_PACKBITS, OP_RAW)),
}


def benchmark(frames: list[bytes], intervals: list[int]) -> list[dict]:
    results = []
    for name, encoder, decoder in (
            ("scanline-packbits", scanline_packbits_encode, scanline_packbits_decode),
            ("gallery-lzss", lzss_encode, lambda packet: lzss_decode(packet, FRAME_SIZE))):
        packed = 0
        largest = 0
        for frame in frames:
            packet = encoder(frame)
            if decoder(packet) != frame:
                raise RuntimeError(f"{name}: host round trip failed")
            packed += 2 + len(packet)
            largest = max(largest, len(packet))
        results.append({"variant": name, "keyframe_interval": None,
                        "packed_bytes": packed, "ratio": packed / (len(frames) * FRAME_SIZE),
                        "largest_frame_bytes": largest, "worst_estimated_cycles": None})
    for interval in intervals:
        packed = 0
        largest = 0
        previous = None
        for index, frame in enumerate(frames):
            packet = encode_xor_frame(frame, previous, keyframe=index % interval == 0)
            if decode_xor_frame(packet, previous) != frame:
                raise RuntimeError("svx2-replacement-copy: host round trip failed")
            packed += 2 + len(packet)
            largest = max(largest, len(packet))
            previous = frame
        results.append({"variant": "svx2-replacement-copy", "keyframe_interval": interval,
                        "packed_bytes": packed, "ratio": packed / (len(frames) * FRAME_SIZE),
                        "largest_frame_bytes": largest, "worst_estimated_cycles": None})
    for name, operations in VARIANTS.items():
        for interval in intervals:
            previous = None
            packed = 0
            worst_cycles = 0
            for index, frame in enumerate(frames):
                packet, stats = encode_frame(frame, previous, keyframe=index % interval == 0,
                                             enabled_ops=operations)
                packed += 2 + len(packet)
                worst_cycles = max(worst_cycles, stats.estimated_cycles)
                previous = frame
            results.append({"variant": name, "keyframe_interval": interval,
                            "packed_bytes": packed, "ratio": packed / (len(frames) * FRAME_SIZE),
                            "worst_estimated_cycles": worst_cycles})
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="concatenated tile-major 4480-byte frames")
    parser.add_argument("output", type=Path, nargs="?", help="length-prefixed video stream")
    parser.add_argument("--codec", choices=("svx2", "svc1"), default="svx2",
                        help="output stream codec (default: svx2)")
    parser.add_argument("--keyframe-interval", type=int, default=30)
    parser.add_argument("--benchmark", action="store_true")
    parser.add_argument("--rgb24", action="store_true",
                        help="input is concatenated 80x56 row-major RGB24; learn one 223-color palette")
    parser.add_argument("--dither", choices=("floyd", "bayer", "none"), default="floyd",
                        help="palette dither for --rgb24 (default: floyd)")
    parser.add_argument("--palette-output", type=Path, help="write 224-entry BGR555 palette")
    parser.add_argument("--compare-keyframes", default="15,30,60,120",
                        help="comma-separated intervals used by --benchmark")
    args = parser.parse_args()
    if args.keyframe_interval < 1:
        parser.error("--keyframe-interval must be positive")
    if args.rgb24:
        frames, palette = quantize_rgb24(args.input, args.dither)
        if args.palette_output:
            args.palette_output.write_bytes(palette)
    else:
        frames = frames_from_file(args.input)
        if args.palette_output:
            parser.error("--palette-output requires --rgb24")
    try:
        intervals = [int(value) for value in args.compare_keyframes.split(",")]
    except ValueError:
        parser.error("--compare-keyframes must contain integers")
    if not intervals or any(value < 1 for value in intervals):
        parser.error("--compare-keyframes values must be positive")
    stream = bytearray()
    decoded_previous = None
    counts: Counter[int] = Counter()
    rows = []
    for index, frame in enumerate(frames):
        keyframe = index % args.keyframe_interval == 0
        if args.codec == "svx2":
            packet = encode_xor_frame(frame, decoded_previous, keyframe=keyframe)
            decoded = decode_xor_frame(packet, decoded_previous)
            commands = ()
            estimated_cycles = None
        else:
            packet, stats = encode_frame(frame, decoded_previous, keyframe=keyframe)
            decoded = decode_frame(packet, decoded_previous)
            commands = stats.commands
            estimated_cycles = stats.estimated_cycles
        if decoded != frame:
            raise RuntimeError(f"frame {index}: host round trip failed")
        stream.extend(len(packet).to_bytes(2, "little"))
        stream.extend(packet)
        counts.update(commands)
        rows.append({"frame": index, "keyframe": keyframe, "raw_bytes": FRAME_SIZE,
                     "packet_bytes": len(packet), "estimated_cycles": estimated_cycles})
        decoded_previous = decoded
    report = {"format": args.codec.upper(), "frame_bytes": FRAME_SIZE, "blocks_per_frame": BLOCK_COUNT,
              "frames": len(frames), "raw_bytes": len(frames) * FRAME_SIZE,
              "packed_bytes": len(stream), "ratio": len(stream) / (len(frames) * FRAME_SIZE),
              "keyframe_interval": args.keyframe_interval,
              "command_counts": {str(k): v for k, v in sorted(counts.items())}, "per_frame": rows}
    if args.benchmark:
        report["comparisons"] = benchmark(frames, intervals)
    if args.output:
        args.output.write_bytes(stream)
    if args.benchmark or not args.output:
        json.dump(report, sys.stdout, indent=2)
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
