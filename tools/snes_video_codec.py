#!/usr/bin/env python3
"""Deterministic 80x56 (70 tile) interframe codec shared by tools and tests.

Frames are 70 consecutive 8x8 Mode 7 tiles (4480 bytes).  Each block chooses
the smallest independently decodable representation.  Packets are deliberately
mapper-neutral: a refill layer may split their bytes at any ROM boundary.
"""

from __future__ import annotations

from dataclasses import dataclass
import struct

MAGIC = b"SVC1"
BLOCK_SIZE = 64
BLOCK_COUNT = 70
FRAME_SIZE = BLOCK_SIZE * BLOCK_COUNT
HEADER = struct.Struct("<4sBBHH")  # magic, flags, blocks, payload bytes, decoded CRC16
XOR_HEADER = struct.Struct("<4sBHH")  # magic, flags, payload bytes, decoded CRC16
FLAG_KEYFRAME = 1

OP_SAME = 0
OP_COPY = 1
OP_SOLID = 2
OP_TWO_COLOR = 3
OP_XOR_PACKBITS = 4
OP_RAW = 5


class CodecError(ValueError):
    pass


@dataclass(frozen=True)
class FrameStats:
    packet_bytes: int
    commands: tuple[int, ...]
    estimated_cycles: int


def crc16(data: bytes) -> int:
    crc = 0xFFFF
    for value in data:
        crc ^= value << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def _packbits(data: bytes) -> bytes:
    """PackBits with deterministic maximal runs and literal packets."""
    out = bytearray()
    i = 0
    while i < len(data):
        run = 1
        while i + run < len(data) and data[i + run] == data[i] and run < 128:
            run += 1
        if run >= 3:
            out.extend((257 - run, data[i]))
            i += run
            continue
        start = i
        i += run
        while i < len(data) and i - start < 128:
            upcoming = 1
            while i + upcoming < len(data) and data[i + upcoming] == data[i] and upcoming < 128:
                upcoming += 1
            if upcoming >= 3:
                break
            if i - start + upcoming > 128:
                break
            i += upcoming
        literal = data[start:i]
        out.append(len(literal) - 1)
        out.extend(literal)
    return bytes(out)


def _unpackbits(data: bytes, expected: int) -> bytes:
    out = bytearray()
    pos = 0
    while pos < len(data) and len(out) < expected:
        control = data[pos]
        pos += 1
        if control <= 127:
            count = control + 1
            if pos + count > len(data):
                raise CodecError("truncated PackBits literal")
            out.extend(data[pos:pos + count])
            pos += count
        elif control >= 129:
            if pos == len(data):
                raise CodecError("truncated PackBits run")
            out.extend((data[pos],) * (257 - control))
            pos += 1
        # 128 is a legal no-op.
        if len(out) > expected:
            raise CodecError("PackBits output overflow")
    if pos != len(data) or len(out) != expected:
        raise CodecError("PackBits length mismatch")
    return bytes(out)


def lzss_encode(data: bytes) -> bytes:
    """Encode the repository's 4 KiB-window/18-byte-match gallery LZSS format."""
    out = bytearray()
    position = 0
    head = [-1] * 256
    previous = [-1] * 4096

    def hash3(pos: int) -> int:
        if pos + 2 >= len(data):
            return 0
        return ((data[pos] * 31) ^ (data[pos + 1] * 17) ^ data[pos + 2]) & 255

    def insert(pos: int) -> None:
        hashed = hash3(pos)
        previous[pos & 4095] = head[hashed]
        head[hashed] = pos

    while position < len(data):
        flag_offset = len(out)
        out.append(0)
        flags = 0
        for bit in range(8):
            if position == len(data):
                break
            best_length = best_distance = 0
            candidate = head[hash3(position)]
            candidates = 0
            while candidate >= 0 and position - candidate <= 4095 and candidates < 64:
                length = 1
                while (length < 18 and position + length < len(data)
                       and data[candidate + length] == data[position + length]):
                    length += 1
                distance = position - candidate
                if length >= 3 and (length > best_length or
                                    (length == best_length and distance < best_distance)):
                    best_length, best_distance = length, distance
                candidate = previous[candidate & 4095]
                candidates += 1
            if best_length >= 3:
                flags |= 1 << bit
                out.extend((best_distance & 255,
                            ((best_distance >> 8) << 4) | (best_length - 3)))
                for inserted in range(position, position + best_length):
                    insert(inserted)
                position += best_length
            else:
                out.append(data[position])
                insert(position)
                position += 1
        out[flag_offset] = flags
    return bytes(out)


def lzss_decode(source: bytes, expected: int) -> bytes:
    out = bytearray()
    position = 0
    while position < len(source) and len(out) < expected:
        flags = source[position]
        position += 1
        for bit in range(8):
            if len(out) == expected:
                break
            if flags & (1 << bit):
                if position + 2 > len(source):
                    raise CodecError("truncated LZSS match")
                low, packed = source[position:position + 2]
                position += 2
                distance = low | ((packed >> 4) << 8)
                length = (packed & 15) + 3
                if not distance or distance > len(out) or len(out) + length > expected:
                    raise CodecError("invalid LZSS match")
                for _ in range(length):
                    out.append(out[-distance])
            else:
                if position == len(source):
                    raise CodecError("truncated LZSS literal")
                out.append(source[position])
                position += 1
    if len(out) != expected or position != len(source):
        raise CodecError("LZSS length mismatch")
    return bytes(out)


def tile_to_raster(frame: bytes) -> bytes:
    if len(frame) != FRAME_SIZE:
        raise CodecError(f"frame must be exactly {FRAME_SIZE} bytes")
    raster = bytearray(FRAME_SIZE)
    source = 0
    for tile_y in range(7):
        for tile_x in range(10):
            for y in range(8):
                target = (tile_y * 8 + y) * 80 + tile_x * 8
                raster[target:target + 8] = frame[source:source + 8]
                source += 8
    return bytes(raster)


def raster_to_tile(raster: bytes) -> bytes:
    if len(raster) != FRAME_SIZE:
        raise CodecError(f"raster must be exactly {FRAME_SIZE} bytes")
    tiled = bytearray()
    for tile_y in range(7):
        for tile_x in range(10):
            for y in range(8):
                start = (tile_y * 8 + y) * 80 + tile_x * 8
                tiled.extend(raster[start:start + 8])
    return bytes(tiled)


def scanline_packbits_encode(frame: bytes) -> bytes:
    raster = tile_to_raster(frame)
    out = bytearray()
    for offset in range(0, FRAME_SIZE, 80):
        encoded = _packbits(raster[offset:offset + 80])
        if len(encoded) > 255:
            raise CodecError("scanline PackBits payload exceeds length byte")
        out.append(len(encoded))
        out.extend(encoded)
    return bytes(out)


def scanline_packbits_decode(source: bytes) -> bytes:
    raster = bytearray()
    position = 0
    for _ in range(56):
        if position == len(source):
            raise CodecError("missing PackBits scanline")
        size = source[position]
        position += 1
        if position + size > len(source):
            raise CodecError("truncated PackBits scanline")
        raster.extend(_unpackbits(source[position:position + size], 80))
        position += size
    if position != len(source):
        raise CodecError("trailing PackBits frame data")
    return raster_to_tile(bytes(raster))


def _replacement_delta(frame: bytes, previous: bytes) -> bytes:
    """Encode SVX2 absolute-literal and previous-copy spans (1..128 bytes)."""
    out = bytearray()
    position = 0
    copy_threshold = 8

    def same_run(start: int) -> int:
        end = start
        while end < FRAME_SIZE and end - start < 128 and frame[end] == previous[end]:
            end += 1
        return end - start

    while position < FRAME_SIZE:
        run = same_run(position)
        if run >= copy_threshold:
            count = run
            out.append(0x80 | (count - 1))
        else:
            end = position
            while end < FRAME_SIZE and end - position < 128:
                if end > position and same_run(end) >= copy_threshold:
                    break
                end += 1
            count = end - position
            out.append(count - 1)
            out.extend(frame[position:end])
        position += count
    return bytes(out)


def encode_xor_frame(frame: bytes, previous: bytes | None = None, *, keyframe: bool = False) -> bytes:
    """Encode an SVX2 PackBits keyframe or replacement/copy delta packet."""
    if len(frame) != FRAME_SIZE:
        raise CodecError(f"frame must be exactly {FRAME_SIZE} bytes")
    if previous is not None and len(previous) != FRAME_SIZE:
        raise CodecError(f"previous frame must be exactly {FRAME_SIZE} bytes")
    keyframe = keyframe or previous is None
    payload = _packbits(frame) if keyframe else _replacement_delta(frame, previous)
    if len(payload) > 0xFFFF:
        raise CodecError("SVX2 payload exceeds packet field")
    return XOR_HEADER.pack(b"SVX2", FLAG_KEYFRAME if keyframe else 0, len(payload), crc16(frame)) + payload


def decode_xor_frame(packet: bytes, previous: bytes | None = None) -> bytes:
    if len(packet) < XOR_HEADER.size:
        raise CodecError("truncated SVX1 header")
    magic, flags, payload_size, expected_crc = XOR_HEADER.unpack_from(packet)
    if magic != b"SVX2" or flags & ~FLAG_KEYFRAME or len(packet) != XOR_HEADER.size + payload_size:
        raise CodecError("invalid SVX2 packet")
    keyframe = bool(flags & FLAG_KEYFRAME)
    if not keyframe and (previous is None or len(previous) != FRAME_SIZE):
        raise CodecError("SVX2 delta frame requires a complete previous frame")
    payload = packet[XOR_HEADER.size:]
    if keyframe:
        result = _unpackbits(payload, FRAME_SIZE)
    else:
        out = bytearray()
        position = 0
        while position < len(payload) and len(out) < FRAME_SIZE:
            control = payload[position]
            position += 1
            count = (control & 0x7f) + 1
            if control & 0x80:
                out.extend(previous[len(out):len(out) + count])
            else:
                if position + count > len(payload):
                    raise CodecError("truncated SVX2 replacement span")
                out.extend(payload[position:position + count])
                position += count
            if len(out) > FRAME_SIZE:
                raise CodecError("SVX2 delta output overflow")
        if position != len(payload) or len(out) != FRAME_SIZE:
            raise CodecError("SVX2 delta length mismatch")
        result = bytes(out)
    if crc16(result) != expected_crc:
        raise CodecError("decoded SVX2 frame CRC mismatch")
    return result


def _two_color(block: bytes) -> bytes | None:
    colors = sorted(set(block))
    if len(colors) != 2:
        return None
    bits = bytearray(8)
    for i, value in enumerate(block):
        if value == colors[1]:
            bits[i >> 3] |= 1 << (i & 7)
    return bytes(colors) + bits


def encode_frame(frame: bytes, previous: bytes | None = None, *, keyframe: bool = False,
                 enabled_ops: frozenset[int] | None = None) -> tuple[bytes, FrameStats]:
    if len(frame) != FRAME_SIZE:
        raise CodecError(f"frame must be exactly {FRAME_SIZE} bytes")
    if previous is not None and len(previous) != FRAME_SIZE:
        raise CodecError(f"previous frame must be exactly {FRAME_SIZE} bytes")
    keyframe = keyframe or previous is None
    enabled = enabled_ops if enabled_ops is not None else frozenset(
        (OP_SAME, OP_COPY, OP_SOLID, OP_TWO_COLOR, OP_XOR_PACKBITS, OP_RAW))
    if OP_RAW not in enabled:
        raise CodecError("raw command must remain enabled as the lossless fallback")
    payload = bytearray()
    commands: list[int] = []
    previous_blocks = {} if keyframe else {
        previous[i:i + BLOCK_SIZE]: i // BLOCK_SIZE
        for i in range(0, FRAME_SIZE, BLOCK_SIZE)
    }
    for offset in range(0, FRAME_SIZE, BLOCK_SIZE):
        block = frame[offset:offset + BLOCK_SIZE]
        old = None if keyframe else previous[offset:offset + BLOCK_SIZE]
        candidates: list[tuple[int, bytes]] = []
        if OP_SAME in enabled and old == block:
            candidates.append((OP_SAME, bytes((OP_SAME,))))
        if OP_COPY in enabled and block in previous_blocks:
            candidates.append((OP_COPY, bytes((OP_COPY, previous_blocks[block]))))
        if OP_SOLID in enabled and len(set(block)) == 1:
            candidates.append((OP_SOLID, bytes((OP_SOLID, block[0]))))
        two = _two_color(block)
        if OP_TWO_COLOR in enabled and two is not None:
            candidates.append((OP_TWO_COLOR, bytes((OP_TWO_COLOR,)) + two))
        if OP_XOR_PACKBITS in enabled and old is not None:
            packed = _packbits(bytes(a ^ b for a, b in zip(block, old)))
            if len(packed) <= 255:
                candidates.append((OP_XOR_PACKBITS, bytes((OP_XOR_PACKBITS, len(packed))) + packed))
        candidates.append((OP_RAW, bytes((OP_RAW,)) + block))
        op, encoded = min(candidates, key=lambda item: (len(item[1]), item[0], item[1]))
        commands.append(op)
        payload.extend(encoded)
    if len(payload) > 0xFFFF:
        raise CodecError("frame payload exceeds packet field")
    packet = HEADER.pack(MAGIC, FLAG_KEYFRAME if keyframe else 0, BLOCK_COUNT,
                         len(payload), crc16(frame)) + payload
    return packet, FrameStats(len(packet), tuple(commands), estimate_cycles(commands, len(payload)))


def decode_frame(packet: bytes, previous: bytes | None = None) -> bytes:
    if len(packet) < HEADER.size:
        raise CodecError("truncated frame header")
    magic, flags, blocks, payload_size, expected_crc = HEADER.unpack_from(packet)
    if magic != MAGIC or flags & ~FLAG_KEYFRAME or blocks != BLOCK_COUNT:
        raise CodecError("invalid frame header")
    if len(packet) != HEADER.size + payload_size:
        raise CodecError("packet length mismatch")
    keyframe = bool(flags & FLAG_KEYFRAME)
    if not keyframe and (previous is None or len(previous) != FRAME_SIZE):
        raise CodecError("delta frame requires a complete previous frame")
    pos = HEADER.size
    out = bytearray()
    for block_index in range(BLOCK_COUNT):
        if pos >= len(packet):
            raise CodecError("missing block command")
        op = packet[pos]
        pos += 1
        old = None if keyframe else previous[block_index * BLOCK_SIZE:(block_index + 1) * BLOCK_SIZE]
        if op == OP_SAME:
            if old is None:
                raise CodecError("same command in keyframe")
            block = old
        elif op == OP_COPY:
            if keyframe or pos >= len(packet):
                raise CodecError("invalid previous-frame copy")
            source = packet[pos]
            pos += 1
            if source >= BLOCK_COUNT:
                raise CodecError("previous-frame copy index out of range")
            block = previous[source * BLOCK_SIZE:(source + 1) * BLOCK_SIZE]
        elif op == OP_SOLID:
            if pos >= len(packet):
                raise CodecError("truncated solid block")
            block = bytes((packet[pos],)) * BLOCK_SIZE
            pos += 1
        elif op == OP_TWO_COLOR:
            if pos + 10 > len(packet):
                raise CodecError("truncated two-color block")
            low, high = packet[pos:pos + 2]
            if low >= high:
                raise CodecError("non-canonical two-color block")
            bitmap = packet[pos + 2:pos + 10]
            pos += 10
            block = bytes(high if bitmap[i >> 3] & (1 << (i & 7)) else low for i in range(BLOCK_SIZE))
        elif op == OP_XOR_PACKBITS:
            if old is None or pos >= len(packet):
                raise CodecError("invalid XOR block")
            size = packet[pos]
            pos += 1
            if pos + size > len(packet):
                raise CodecError("truncated XOR block")
            delta = _unpackbits(packet[pos:pos + size], BLOCK_SIZE)
            pos += size
            block = bytes(a ^ b for a, b in zip(old, delta))
        elif op == OP_RAW:
            if pos + BLOCK_SIZE > len(packet):
                raise CodecError("truncated raw block")
            block = packet[pos:pos + BLOCK_SIZE]
            pos += BLOCK_SIZE
        else:
            raise CodecError(f"unknown block command {op}")
        out.extend(block)
    if pos != len(packet):
        raise CodecError("trailing frame payload")
    result = bytes(out)
    if crc16(result) != expected_crc:
        raise CodecError("decoded frame CRC mismatch")
    return result


def estimate_cycles(commands: list[int] | tuple[int, ...], payload_size: int) -> int:
    """Conservative model for comparisons; replace with measured 65816 figures later."""
    costs = {OP_SAME: 40, OP_COPY: 520, OP_SOLID: 460, OP_TWO_COLOR: 900,
             OP_XOR_PACKBITS: 1300, OP_RAW: 520}
    return 250 + payload_size * 3 + sum(costs[op] for op in commands)
