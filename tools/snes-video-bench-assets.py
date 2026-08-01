#!/usr/bin/env python3
"""Select median/worst real-video packets and emit a deterministic C benchmark header."""

from __future__ import annotations

import argparse
from pathlib import Path

from snes_video_codec import (FRAME_SIZE, decode_xor_frame, encode_frame,
                              encode_xor_frame, lzss_encode)


def c_array(name: str, data: bytes) -> str:
    rows = [", ".join(f"0x{value:02x}" for value in data[i:i + 16])
            for i in range(0, len(data), 16)]
    body = ",\n  ".join(rows)
    return f"static const uint8_t {name}[{len(data)}] = {{\n  {body}\n}};\n"


def select(encoded: list[tuple[int, bytes, bytes | None, bytes]]) -> dict[str, tuple[int, bytes, bytes | None, bytes]]:
    ordered = sorted(encoded, key=lambda item: (len(item[1]), item[0]))
    return {"MEDIAN": ordered[len(ordered) // 2], "WORST": ordered[-1]}


def frame_check(frame: bytes) -> int:
    """Mod-2^16 Fletcher, mirrored byte-for-byte by frame_check() in the bench ROM."""
    a = b = 0
    for value in frame:
        a = (a + value) & 0xffff
        b = (b + a) & 0xffff
    return (a ^ b) & 0xffff


def emit_stream(lines: list[str], frames: list[bytes], count: int, interval: int,
                start: int, stream_output: Path | None,
                parser: argparse.ArgumentParser) -> None:
    """Emit a real multi-packet stream: packets are packed separately (HiROM bank
    $C1) and reached through a 32-bit offset table, exactly like the reel."""
    if count < 2 or count > len(frames):
        parser.error(f"--stream-frames must be 2..{len(frames)}")
    if start < 0 or start + count > len(frames):
        parser.error(f"--stream-start must be 0..{len(frames) - count}")
    packets: list[bytes] = []
    keyframes: list[int] = []
    checks: list[int] = []
    decoded: list[bytes] = []
    if stream_output is None:
        parser.error("--stream-frames requires --stream-output")
    for index in range(count):
        keyframe = index % interval == 0
        previous = decoded[-1] if index else None
        packet = encode_xor_frame(frames[start + index], previous, keyframe=keyframe)
        # Round-trip on the host so the target's expected values describe the
        # decoder's real output, not the encoder's input.
        replay = decode_xor_frame(packet, previous)
        if replay != frames[start + index]:
            parser.error(f"host round-trip failed for stream frame {index}")
        packets.append(packet)
        keyframes.append(1 if keyframe else 0)
        decoded.append(replay)
        checks.append(frame_check(replay))
    stream = b"".join(packets)
    stream_output.write_bytes(stream)
    offsets = [0]
    for packet in packets:
        offsets.append(offsets[-1] + len(packet))
    lines.extend((
        "#define VIDEO_BENCH_STREAM_ASSETS 1",
        f"#define VIDEO_BENCH_STREAM_FRAMES {count}u",
        f"#define VIDEO_BENCH_STREAM_START {start}u",
        f"#define VIDEO_BENCH_STREAM_KEYFRAME_INTERVAL {interval}u",
        f"#define VIDEO_BENCH_STREAM_BYTES {len(stream)}u",
        f"#define VIDEO_BENCH_STREAM_CAPACITY {max(len(p) for p in packets)}u",
        "#define VIDEO_BENCH_STREAM_BASE_BANK 0xc1u",
        f"static const uint32_t bench_stream_offsets[{len(offsets)}] = {{",
        "  " + ", ".join(f"0x{value:06x}ul" for value in offsets),
        "};",
        f"static const uint8_t bench_stream_keyframes[{count}] = {{",
        "  " + ", ".join(str(value) for value in keyframes),
        "};",
        f"static const uint16_t bench_stream_checks[{count}] = {{",
        "  " + ", ".join(f"0x{value:04x}u" for value in checks),
        "};",
        "",
        c_array("bench_stream_final", decoded[-1]),
    ))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tiles", type=Path, help="concatenated 4480-byte tile-major frames")
    parser.add_argument("output", type=Path)
    parser.add_argument("--palette", type=Path,
                        help="optional 448-byte SNES palette for a visible benchmark ROM")
    parser.add_argument("--keyframe-interval", type=int, default=60)
    parser.add_argument("--stream-frames", type=int,
                        help="emit a real multi-packet ring-refill stream of N frames "
                             "instead of the single-packet case table")
    parser.add_argument("--stream-start", type=int, default=0,
                        help="first corpus frame of the stream slice")
    parser.add_argument("--stream-output", type=Path,
                        help="packed stream binary, installed at HiROM bank $C1")
    args = parser.parse_args()
    data = args.tiles.read_bytes()
    if not data or len(data) % FRAME_SIZE:
        parser.error("tile corpus size is not a positive multiple of 4480")
    frames = [data[i:i + FRAME_SIZE] for i in range(0, len(data), FRAME_SIZE)]
    packets: dict[str, list[tuple[int, bytes, bytes | None, bytes]]] = {
        "SVX": [], "SVC": [], "LZSS": []}
    for index, frame in enumerate(frames):
        previous = frames[index - 1] if index else None
        keyframe = index % args.keyframe_interval == 0
        packets["SVX"].append((index, encode_xor_frame(frame, previous, keyframe=keyframe),
                               None if keyframe else previous, frame))
        packet, _ = encode_frame(frame, previous, keyframe=keyframe)
        packets["SVC"].append((index, packet, None if keyframe else previous, frame))
        packets["LZSS"].append((index, lzss_encode(frame), None, frame))

    lines = ["// GENERATED by tools/snes-video-bench-assets.py; do not edit.",
             "#ifndef SNES_VIDEO_BENCH_ASSETS_H", "#define SNES_VIDEO_BENCH_ASSETS_H", ""]
    if args.palette:
        palette = args.palette.read_bytes()
        if len(palette) != 448:
            parser.error(f"palette must be exactly 448 bytes, got {len(palette)}")
        lines.append(c_array("bench_palette", palette))
        lines.append("#define VIDEO_BENCH_HAS_PALETTE 1\n")
    if args.stream_frames is not None:
        emit_stream(lines, frames, args.stream_frames, args.keyframe_interval,
                    args.stream_start, args.stream_output, parser)
        lines.append("#endif")
        args.output.write_text("\n".join(lines) + "\n")
        return 0
    case = 0
    for codec in ("SVX", "SVC", "LZSS"):
        for rank, (frame_index, packet, previous, expected) in select(packets[codec]).items():
            macro = f"BENCH_{codec}_{rank}"
            lines.extend((f"#if VIDEO_BENCH_CASE == {case}", f"#define VIDEO_BENCH_NAME \"{codec.lower()}-{rank.lower()}\"",
                          f"#define VIDEO_BENCH_CODEC_{codec} 1", f"#define VIDEO_BENCH_FRAME {frame_index}u",
                          f"#define VIDEO_BENCH_PACKET_SIZE {len(packet)}u"))
            lines.append(c_array("bench_packet", packet))
            if previous is not None:
                lines.append(c_array("bench_previous", previous))
                lines.append("#define VIDEO_BENCH_PREVIOUS bench_previous")
            else:
                lines.append("#define VIDEO_BENCH_PREVIOUS ((const uint8_t *)0)")
            lines.append(c_array("bench_expected", expected))
            lines.append(f"#define {macro} 1\n#endif\n")
            case += 1
    raw = frames[len(frames) // 2]
    lines.extend((f"#if VIDEO_BENCH_CASE == {case}", '#define VIDEO_BENCH_NAME "raw-copy"',
                  "#define VIDEO_BENCH_CODEC_RAW 1", f"#define VIDEO_BENCH_FRAME {len(frames) // 2}u",
                  f"#define VIDEO_BENCH_PACKET_SIZE {len(raw)}u", c_array("bench_packet", raw),
                  "#define VIDEO_BENCH_PREVIOUS ((const uint8_t *)0)", c_array("bench_expected", raw),
                  "#endif", ""))
    # Case 7: the keyframe path. Both median and worst above are deltas, so the
    # PackBits literal/run kernel had never been measured in these units even
    # though one frame in --keyframe-interval takes it.
    key_candidates = [item for item in packets["SVX"]
                      if item[0] % args.keyframe_interval == 0]
    key_index, key_packet, _, key_expected = max(
        key_candidates, key=lambda item: (len(item[1]), item[0]))
    case += 1
    lines.extend((f"#if VIDEO_BENCH_CASE == {case}", '#define VIDEO_BENCH_NAME "svx-keyframe"',
                  "#define VIDEO_BENCH_CODEC_SVX 1", f"#define VIDEO_BENCH_FRAME {key_index}u",
                  f"#define VIDEO_BENCH_PACKET_SIZE {len(key_packet)}u",
                  c_array("bench_packet", key_packet),
                  "#define VIDEO_BENCH_PREVIOUS ((const uint8_t *)0)",
                  c_array("bench_expected", key_expected),
                  "#define BENCH_SVX_KEYFRAME 1", "#endif", ""))
    lines.extend((f"#if VIDEO_BENCH_CASE < 0 || VIDEO_BENCH_CASE > {case}",
                  f'#error "VIDEO_BENCH_CASE must be 0..{case}"',
                  "#endif", "#endif"))
    args.output.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
