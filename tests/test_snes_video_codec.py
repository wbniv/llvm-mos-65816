import random
import re
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[1] / "tools"))
from snes_video_codec import (  # noqa: E402
    BLOCK_SIZE, CodecError, FRAME_SIZE, OP_COPY, OP_RAW, OP_SAME, OP_SOLID,
    OP_TWO_COLOR, OP_XOR_PACKBITS, decode_frame, decode_xor_frame, encode_frame, encode_xor_frame, lzss_decode, lzss_encode,
    raster_to_tile, scanline_packbits_decode, scanline_packbits_encode, tile_to_raster,
)


def load_packer_module():
    import importlib.util
    spec = importlib.util.spec_from_file_location("snes_video_pack", Path(__file__).parents[1] / "tools/snes-video-pack.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def blocks(items):
    return b"".join(items)


def test_round_trip_exercises_every_command():
    rng = random.Random(65816)
    previous_blocks = [bytes(rng.randrange(256) for _ in range(BLOCK_SIZE)) for _ in range(70)]
    previous = blocks(previous_blocks)
    current = list(previous_blocks)
    current[1] = previous_blocks[9]
    current[2] = bytes([17]) * BLOCK_SIZE
    current[3] = bytes([4, 9]) * 32
    current[4] = bytes([previous_blocks[4][0] ^ 1]) + previous_blocks[4][1:]
    current[5] = bytes(rng.randrange(256) for _ in range(BLOCK_SIZE))
    packet, stats = encode_frame(blocks(current), previous)
    assert decode_frame(packet, previous) == blocks(current)
    assert {OP_SAME, OP_COPY, OP_SOLID, OP_TWO_COLOR, OP_XOR_PACKBITS, OP_RAW} <= set(stats.commands)


def test_keyframe_is_independent_and_deterministic():
    frame = bytes((i * 37 + i // 64) & 255 for i in range(FRAME_SIZE))
    first, _ = encode_frame(frame, keyframe=True)
    second, _ = encode_frame(frame, keyframe=True)
    assert first == second
    assert decode_frame(first) == frame


def test_command_subsets_remain_lossless():
    rng = random.Random(12)
    previous = bytes(rng.randrange(256) for _ in range(FRAME_SIZE))
    frame = previous[:64] + bytes([9]) * 64 + previous[128:]
    for operations in ({OP_RAW}, {OP_SAME, OP_RAW}, {OP_SAME, OP_XOR_PACKBITS, OP_RAW}):
        packet, _ = encode_frame(frame, previous, enabled_ops=frozenset(operations))
        assert decode_frame(packet, previous) == frame


def test_intraframe_baselines_round_trip():
    frame = bytes((i * 17 + i // 80) & 255 for i in range(FRAME_SIZE))
    assert raster_to_tile(tile_to_raster(frame)) == frame
    packed = scanline_packbits_encode(frame)
    assert scanline_packbits_decode(packed) == frame
    packed = lzss_encode(frame)
    assert lzss_decode(packed, FRAME_SIZE) == frame


def test_whole_frame_xor_packbits_round_trip():
    rng = random.Random(44)
    previous = bytes(rng.randrange(224) + 1 for _ in range(FRAME_SIZE))
    current = bytearray(previous)
    current[100:180] = bytes([7]) * 80
    keyframe = encode_xor_frame(previous, keyframe=True)
    delta = encode_xor_frame(bytes(current), previous)
    assert decode_xor_frame(keyframe) == previous
    assert decode_xor_frame(delta, previous) == bytes(current)


def test_svx2_delta_uses_copy_and_replacement_spans():
    previous = bytes([1]) * FRAME_SIZE
    current = bytearray(previous)
    current[20:28] = bytes(range(8))
    packet = encode_xor_frame(bytes(current), previous)
    assert packet[:4] == b"SVX2"
    payload = packet[9:]
    assert any(control & 0x80 for control in payload)
    assert decode_xor_frame(packet, previous) == bytes(current)


def test_packbits_literal_boundary_round_trip():
    rng = random.Random(123)
    frame = bytes(rng.randrange(256) for _ in range(FRAME_SIZE))
    assert decode_xor_frame(encode_xor_frame(frame, keyframe=True)) == frame


@pytest.mark.parametrize("mutation", ["truncate", "append", "opcode", "crc"])
def test_corrupt_packets_are_rejected(mutation):
    packet, _ = encode_frame(bytes([3]) * FRAME_SIZE, keyframe=True)
    damaged = bytearray(packet)
    if mutation == "truncate":
        damaged.pop()
    elif mutation == "append":
        damaged.append(0)
    elif mutation == "opcode":
        damaged[10] = 255
    else:
        damaged[8] ^= 1
    with pytest.raises(CodecError):
        decode_frame(bytes(damaged))


def test_wrong_size_and_missing_previous_are_rejected():
    with pytest.raises(CodecError):
        encode_frame(b"short")
    packet, _ = encode_frame(bytes(FRAME_SIZE), bytes(FRAME_SIZE))
    with pytest.raises(CodecError):
        decode_frame(packet)


def test_c_decoder_matches_python(tmp_path):
    executable = tmp_path / "svc-harness"
    root = Path(__file__).parents[1]
    subprocess.run(["cc", "-std=c99", "-Wall", "-Wextra", "-Werror", "-O2",
                    str(root / "tests/snes_video_codec_harness.c"),
                    str(root / "examples/snes/snes-video-stream.c"),
                    str(root / "examples/snes/snes-video-codec.c"), "-o", str(executable)], check=True)
    rng = random.Random(0x65816)
    previous = bytes(rng.randrange(224) + 1 for _ in range(FRAME_SIZE))
    current = bytearray(previous)
    current[64:128] = previous[640:704]
    current[128:192] = bytes([7]) * 64
    current[192:256] = bytes([3, 8]) * 32
    current[256] ^= 1
    packet, _ = encode_frame(bytes(current), previous)
    process = subprocess.run([str(executable)], input=len(packet).to_bytes(2, "little") + previous + packet,
                             stdout=subprocess.PIPE, check=True)
    assert process.stdout == bytes(current)

    xor_packet = encode_xor_frame(bytes(current), previous)
    process = subprocess.run([str(executable)],
                             input=len(xor_packet).to_bytes(2, "little") + previous + xor_packet,
                             stdout=subprocess.PIPE, check=True)
    assert process.stdout == bytes(current)


def test_segment_cursor_crosses_canonical_banks(tmp_path):
    executable = tmp_path / "stream-harness"
    root = Path(__file__).parents[1]
    subprocess.run(["cc", "-std=c99", "-Wall", "-Wextra", "-Werror", "-O2",
                    str(root / "tests/snes_video_stream_harness.c"),
                    str(root / "examples/snes/snes-video-stream.c"),
                    str(root / "examples/snes/snes-video-codec.c"),
                    "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)


def test_snes_dma_segment_copy_plan(tmp_path):
    executable = tmp_path / "dma-harness"
    root = Path(__file__).parents[1]
    subprocess.run(["cc", "-std=c99", "-Wall", "-Wextra", "-Werror", "-O2",
                    str(root / "tests/snes_video_dma_harness.c"),
                    str(root / "examples/snes/snes-video-dma.c"),
                    "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)


def run_reel_assets(tmp_path, *extra):
    root = Path(__file__).parents[1]
    tiles = tmp_path / "frames.tiles"
    palette = tmp_path / "palette.bin"
    output = tmp_path / "assets.h"
    tiles.write_bytes(bytes(FRAME_SIZE * 3))
    palette.write_bytes(bytes((0, 0, 0xff, 0x7f)) + bytes(444))
    return subprocess.run(
        [sys.executable, str(root / "tools/snes-video-reel-assets.py"),
         "--frames", "3", *extra, str(tiles), str(palette), str(output)],
        text=True, capture_output=True), output


def test_reel_assets_emit_cut_aware_dashboard_segments(tmp_path):
    process, output = run_reel_assets(
        tmp_path, "--segment", "0:LAUNCH", "--segment", "1:RETURN",
        "--segment", "2:PRESS-SITE CAMERA")
    assert process.returncode == 0, process.stderr
    header = output.read_text()
    assert "#define VIDEO_REEL_SEGMENT_COUNT 3u" in header
    assert "0u, 1u, 2u" in header
    assert '"LAUNCH"' in header
    assert '"PRESS-SITE CAMERA"' in header


@pytest.mark.parametrize("segments, message", [
    (("1:FIRST",), "first segment must start at frame zero"),
    (("0:FIRST", "0:SECOND"), "strictly increasing"),
    (("0:",), "1 through 18"),
    (("0:THIS LABEL IS FAR TOO LONG",), "1 through 18"),
    (("0:FIRST", "3:PAST END"), "outside the 3-frame reel"),
])
def test_reel_assets_reject_invalid_dashboard_segments(tmp_path, segments, message):
    args = tuple(item for segment in segments for item in ("--segment", segment))
    process, _ = run_reel_assets(tmp_path, *args)
    assert process.returncode != 0
    assert message in process.stderr


def test_checksum_tool_marks_fastrom_and_recomputes_checksum(tmp_path):
    root = Path(__file__).parents[1]
    rom_path = tmp_path / "fast.sfc"
    rom = bytearray(0x8000)
    rom[0x7FDC:0x7FE0] = b"\xff\xff\x00\x00"
    rom_path.write_bytes(rom)
    subprocess.run([sys.executable, str(root / "tools/snes-checksum.py"),
                    "--fastrom", str(rom_path)], check=True)
    patched = rom_path.read_bytes()
    checksum = int.from_bytes(patched[0x7FDE:0x7FE0], "little")
    complement = int.from_bytes(patched[0x7FDC:0x7FDE], "little")
    assert patched[0x7FD5] == 0x30
    assert checksum ^ complement == 0xFFFF
    assert sum(patched) & 0xFFFF == checksum

def test_rgb_quantizer_reserves_indices_and_tiles(tmp_path):
    packer = load_packer_module()
    source = tmp_path / "frames.rgb"
    source.write_bytes(bytes((x * 3 + y * 5 + frame * 7) & 255
                             for frame in range(2) for y in range(56) for x in range(80)
                             for _channel in range(3)))
    outputs = {}
    for dither in ("floyd", "bayer", "none"):
        frames, palette = packer.quantize_rgb24(source, dither)
        outputs[dither] = frames
        assert len(frames) == 2 and all(len(frame) == FRAME_SIZE for frame in frames)
        assert len(palette) == 448
        assert palette[:4] == bytes((0x00, 0x00, 0xff, 0x7f))
        assert min(frames[0]) >= 2 and max(frames[0]) <= 223
    assert outputs["floyd"] != outputs["bayer"]


def test_reel_assets_can_pin_a_frame_to_exhirom_region_b(tmp_path):
    stream = tmp_path / "stream.bin"
    process, output = run_reel_assets(
        tmp_path, "--packed-far", "--exhirom", "--exhirom-seam-frame", "1",
        "--stream-output", str(stream))
    assert process.returncode == 0, process.stderr
    header = output.read_text()
    assert "#define VIDEO_REEL_HIROM_BASE_BANK 0xc1u" in header
    assert "#define VIDEO_REEL_EXHIROM_SEAM_FRAME 1u" in header
    offsets_body = header.split("reel_packet_offsets", 1)[1].split("};", 1)[0]
    offsets = [int(value) for value in re.findall(r"(\d+)ul", offsets_body)]
    assert offsets[1] == 0x3f0000
    assert len(stream.read_bytes()) > 0x3f0000
