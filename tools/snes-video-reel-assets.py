#!/usr/bin/env python3
"""Emit a small, deterministic SVX2 reel as a C header."""

from __future__ import annotations

import argparse
from pathlib import Path

from snes_video_codec import FRAME_SIZE, decode_xor_frame, encode_xor_frame


def byte_rows(data: bytes) -> str:
    return ",\n    ".join(
        ", ".join(f"0x{value:02x}" for value in data[offset:offset + 16])
        for offset in range(0, len(data), 16)
    )


def frame_check(frame: bytes) -> int:
    """Mod-2^16 Fletcher, mirrored byte-for-byte by frame_check() in the ROM.

    Identical to frame_check() in tools/snes-video-bench-assets.py — the two
    must stay in step because both describe the same decoder output.
    """
    a = b = 0
    for value in frame:
        a = (a + value) & 0xffff
        b = (b + a) & 0xffff
    return (a ^ b) & 0xffff


def dashboard_palette(palette: bytes, fixup: bool,
                      parser: argparse.ArgumentParser, what: str) -> bytes:
    """Entries 0/1 are the HUD's black/white ink and are not content.

    A corpus whose quantizer was free to use both entries (the Apollo daylight
    set puts near-white 0x77ff in entry 1) is still usable: --dashboard-palette-fixup
    rewrites just those two entries. Tiles and the packed stream are untouched,
    so this changes display colour only, never the decoded bytes.
    """
    if palette[:4] == bytes((0x00, 0x00, 0xff, 0x7f)):
        return palette
    if not fixup:
        parser.error(f"{what} entries 0/1 must remain dashboard black/white "
                     f"(got 0x{palette[1] << 8 | palette[0]:04x}/"
                     f"0x{palette[3] << 8 | palette[2]:04x}); "
                     f"pass --dashboard-palette-fixup to override them")
    return bytes((0x00, 0x00, 0xff, 0x7f)) + palette[4:]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tiles", type=Path, help="concatenated 4480-byte tile-major frames")
    parser.add_argument("palette", type=Path, help="448-byte BGR555 palette")
    parser.add_argument("output", type=Path, help="generated C header")
    parser.add_argument("--frames", type=int, default=4)
    parser.add_argument("--packed-far", action="store_true",
                        help="emit one contiguous HiROM far-data stream and offsets")
    parser.add_argument("--exhirom", action="store_true",
                        help="map packed stream offset zero after the ExHiROM FastROM code mirror / bank $C1")
    parser.add_argument("--exhirom-seam-frame", type=int, default=0,
                        help="place this frame at the region-B seam by adding deterministic leading padding")
    parser.add_argument("--stream-output", type=Path,
                        help="write packed bytes separately instead of a C initializer")
    parser.add_argument("--first-tiles", type=Path,
                        help="optional first video corpus, placed before positional corpus")
    parser.add_argument("--first-palette", type=Path,
                        help="448-byte palette for --first-tiles")
    parser.add_argument("--first-frames", type=int, default=0)
    parser.add_argument("--keyframe-interval", type=int, default=0,
                        help="emit a seek keyframe at this frame interval")
    parser.add_argument("--segment", action="append", default=[], metavar="START:LABEL",
                        help="dashboard segment start frame and label (repeatable)")
    parser.add_argument("--frame-checks", action="store_true",
                        help="emit per-frame Fletcher16 checks plus the final decoded "
                             "frame, for a whole-loop byte-correctness gate on target")
    parser.add_argument("--dashboard-palette-fixup", action="store_true",
                        help="rewrite palette entries 0/1 to black/white instead of "
                             "rejecting a corpus palette that uses them")
    parser.add_argument("--palette-output", type=Path,
                        help="write the effective palette (post-fixup) for the "
                             "screenshot checker to compare against")
    args = parser.parse_args()

    data = args.tiles.read_bytes()
    palette = args.palette.read_bytes()
    if not data or len(data) % FRAME_SIZE:
        parser.error("tile corpus must contain whole 4480-byte frames")
    if len(palette) != 448:
        parser.error(f"palette must be exactly 448 bytes, got {len(palette)}")
    palette = dashboard_palette(palette, args.dashboard_palette_fixup, parser, "palette")
    if args.palette_output:
        args.palette_output.write_bytes(palette)
    available = len(data) // FRAME_SIZE
    if args.frames < 2 or args.frames > available:
        parser.error(f"--frames must be between 2 and {available}")

    frames = [data[i * FRAME_SIZE:(i + 1) * FRAME_SIZE] for i in range(args.frames)]
    palettes = [palette]
    second_start = 0
    if args.first_tiles or args.first_palette or args.first_frames:
        if not (args.first_tiles and args.first_palette and args.first_frames):
            parser.error("--first-tiles, --first-palette, and --first-frames are required together")
        first_data = args.first_tiles.read_bytes()
        first_palette = args.first_palette.read_bytes()
        if len(first_data) % FRAME_SIZE or args.first_frames > len(first_data) // FRAME_SIZE:
            parser.error("first tile corpus does not contain the requested whole frames")
        if len(first_palette) != 448:
            parser.error("first palette must be 448 bytes")
        first_palette = dashboard_palette(first_palette, args.dashboard_palette_fixup,
                                          parser, "first palette")
        first = [first_data[i * FRAME_SIZE:(i + 1) * FRAME_SIZE]
                 for i in range(args.first_frames)]
        second_start = len(first)
        frames = first + frames
        palettes = [first_palette, palette]
    if args.keyframe_interval < 0:
        parser.error("--keyframe-interval must be non-negative")
    if args.exhirom_seam_frame:
        if not args.exhirom or not args.packed_far or not args.stream_output:
            parser.error("--exhirom-seam-frame requires --exhirom, --packed-far, and --stream-output")
        if args.exhirom_seam_frame >= len(frames):
            parser.error("--exhirom-seam-frame must be less than the frame count")
    segments: list[tuple[int, str]] = []
    for spec in args.segment:
        try:
            start_text, label = spec.split(":", 1)
            start = int(start_text, 10)
        except ValueError:
            parser.error(f"invalid --segment {spec!r}; expected START:LABEL")
        if not label or len(label) > 18:
            parser.error("segment labels must contain 1 through 18 characters")
        if any(ord(ch) < 0x20 or ord(ch) > 0x7e for ch in label):
            parser.error("segment labels must contain printable ASCII only")
        if start < 0 or start >= len(frames):
            parser.error(f"segment start {start} is outside the {len(frames)}-frame reel")
        if segments and start <= segments[-1][0]:
            parser.error("segment starts must be strictly increasing")
        segments.append((start, label))
    if segments and segments[0][0] != 0:
        parser.error("the first segment must start at frame zero")
    packets: list[bytes] = []
    previous = None
    for index, frame in enumerate(frames):
        # Only initial boot requires an independent packet in the sequential
        # stream. Scene cuts remain ordinary deltas; random access uses the
        # separate seek-keyframe table below.
        keyframe = index == 0
        if keyframe:
            previous = None
        packet = encode_xor_frame(frame, previous, keyframe=keyframe)
        if decode_xor_frame(packet, previous) != frame:
            raise RuntimeError(f"frame {index}: SVX2 host round trip failed")
        packets.append(packet)
        previous = frame

    seek_packets: list[bytes] = []
    if args.keyframe_interval:
        for index in range(0, len(frames), args.keyframe_interval):
            packet = encode_xor_frame(frames[index], None, keyframe=True)
            if decode_xor_frame(packet, None) != frames[index]:
                raise RuntimeError(f"seek frame {index}: SVX2 host round trip failed")
            seek_packets.append(packet)

    loop_packet = encode_xor_frame(frames[0], frames[-1], keyframe=False)
    if decode_xor_frame(loop_packet, frames[-1]) != frames[0]:
        raise RuntimeError("loop delta: SVX2 host round trip failed")

    all_packets = packets + seek_packets + [loop_packet]
    maximum = max(map(len, all_packets))
    lines = [
        "// GENERATED by tools/snes-video-reel-assets.py; do not edit.",
        "#ifndef SNES_VIDEO_REEL_ASSETS_H",
        "#define SNES_VIDEO_REEL_ASSETS_H",
        "#include <stdint.h>",
        f"#define VIDEO_REEL_FRAME_COUNT {len(frames)}u",
        f"#define VIDEO_REEL_PACKET_CAPACITY {maximum}u",
        f"#define VIDEO_REEL_TOTAL_PACKET_BYTES {sum(map(len, all_packets))}u",
        "static const uint8_t reel_palette[448] = {",
        f"    {byte_rows(palettes[0])}",
        "};",
    ]
    if args.keyframe_interval:
        lines.append(f"#define VIDEO_REEL_SEEK_INTERVAL {args.keyframe_interval}u")
    if segments:
        lines.extend((
            f"#define VIDEO_REEL_SEGMENT_COUNT {len(segments)}u",
            f"static const uint16_t reel_segment_starts[{len(segments)}] = {{",
            "  " + ", ".join(f"{start}u" for start, _ in segments),
            "};",
            f"static const char reel_segment_labels[{len(segments)}][19] = {{",
        ))
        for _, label in segments:
            escaped = label.replace("\\", "\\\\").replace('"', '\\"')
            lines.append(f'  "{escaped}",')
        lines.append("};")
    if second_start:
        lines.append(f"#define VIDEO_REEL_SECOND_START {second_start}u")
        if palettes[1] != palettes[0]:
            lines.extend((
                "#define VIDEO_REEL_SECOND_PALETTE 1",
                "static const uint8_t reel_palette_second[448] = {",
                f"    {byte_rows(palettes[1])}",
                "};",
            ))
    if args.packed_far:
        leading_padding = 0
        if args.exhirom_seam_frame:
            before_seam = sum(map(len, packets[:args.exhirom_seam_frame]))
            if before_seam > 0x3f0000:
                parser.error("packets before --exhirom-seam-frame already exceed region A")
            leading_padding = 0x3f0000 - before_seam
        stream = bytes(leading_padding) + b"".join(all_packets)
        if args.stream_output:
            args.stream_output.write_bytes(stream)
        offsets = [leading_padding]
        for packet in packets:
            offsets.append(offsets[-1] + len(packet))
        seek_offsets = [offsets[-1]]
        for packet in seek_packets:
            seek_offsets.append(seek_offsets[-1] + len(packet))
        if not args.stream_output:
            lines.extend((
                "static const uint8_t reel_packet_stream[]",
                "    __attribute__((section(\".far_rodata\"))) = {",
                f"    {byte_rows(stream)}",
                "};",
            ))
        lines.extend((
            "#define VIDEO_REEL_PACKED_FAR 1",
            f"#define VIDEO_REEL_HIROM_BASE_BANK 0xc1u",
            f"#define VIDEO_REEL_STREAM_BYTES {len(stream)}u",
            f"static const uint32_t reel_packet_offsets[{len(offsets)}] = {{",
            "  " + ", ".join(f"{offset}ul" for offset in offsets),
            "};",
        ))
        if args.exhirom:
            lines.append("#define VIDEO_REEL_EXHIROM 1")
        if args.exhirom_seam_frame:
            lines.append(f"#define VIDEO_REEL_EXHIROM_SEAM_FRAME {args.exhirom_seam_frame}u")
        if seek_packets:
            lines.extend((
                f"#define VIDEO_REEL_SEEK_COUNT {len(seek_packets)}u",
                f"static const uint32_t reel_seek_packet_offsets[{len(seek_offsets)}] = {{",
                "  " + ", ".join(f"{offset}ul" for offset in seek_offsets),
                "};",
            ))
        loop_start = seek_offsets[-1]
        lines.extend((
            "#define VIDEO_REEL_LOOP_DELTA 1",
            f"#define VIDEO_REEL_LOOP_PACKET_OFFSET {loop_start}ul",
            f"#define VIDEO_REEL_LOOP_PACKET_SIZE {len(loop_packet)}u",
        ))
    else:
        lines.append(f"static const uint8_t reel_packets[{len(frames)}][{maximum}] = {{")
        for packet in packets:
            lines.extend(("  {", f"    {byte_rows(packet)}", "  },"))
        lines.extend((
            "};",
            f"static const uint16_t reel_packet_sizes[{len(frames)}] = {{",
            "  " + ", ".join(f"{len(packet)}u" for packet in packets),
            "};",
        ))
    lines.extend((
        f"static const uint16_t reel_frame_crcs[{len(frames)}] = {{",
        "  " + ", ".join(f"0x{packet[7] | (packet[8] << 8):04x}u" for packet in packets),
        "};",
    ))
    if args.frame_checks:
        # Every packet above was round-tripped through decode_xor_frame(), so
        # frames[i] is literally what the target decoder must produce. Checking
        # all of them pins the entire delta chain, not just the keyframe.
        lines.extend((
            "#define VIDEO_REEL_FRAME_CHECKS 1",
            f"static const uint16_t reel_frame_checks[{len(frames)}] = {{",
            "  " + ", ".join(f"0x{frame_check(frame):04x}u" for frame in frames),
            "};",
            f"static const uint8_t reel_final_frame[{FRAME_SIZE}] = {{",
            f"    {byte_rows(frames[-1])}",
            "};",
        ))
    lines.extend((
        "#endif",
        "",
    ))
    args.output.write_text("\n".join(lines))
    print(f"frames={len(frames)} packets={sum(map(len, packets))} "
          f"seek={sum(map(len, seek_packets))} loop={len(loop_packet)} "
          f"padding={leading_padding if args.packed_far else 0} "
          f"total={sum(map(len, all_packets))} max={maximum}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
