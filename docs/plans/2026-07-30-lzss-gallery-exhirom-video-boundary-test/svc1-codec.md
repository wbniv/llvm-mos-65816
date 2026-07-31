# SVC1 block-video packet format

SVC1 is the mapper-neutral candidate codec for 80 × 56 indexed Mode 7 video. It is not yet the
selected shipping codec: selection still requires measurements over the quantized presentation
clip and on-target cycle measurements.

## Frame representation

- A decoded frame is exactly 4,480 bytes: 70 consecutive 8 × 8 tiles in row-major tile order.
- Every pixel is one palette index. Palette ownership constraints are enforced by the video packer,
  outside the codec.
- Delta frames require distinct previous and output buffers. Keyframes require no previous frame.
- Packets contain no ROM address or segmentation information. The decoder reads through a callback,
  allowing the mapper layer to refill across CPU-bank and physical-device boundaries.

## Packet

All multibyte integers are little-endian.

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 4 | ASCII `SVC1` |
| 4 | 1 | flags; bit 0 is keyframe, all other bits must be zero |
| 5 | 1 | block count; must be 70 |
| 6 | 2 | command payload size |
| 8 | 2 | CRC-16/CCITT-FALSE of the decoded 4,480 bytes |
| 10 | variable | exactly 70 block commands |

The decoder rejects truncated packets, trailing bytes, unknown flags or commands, invalid copy
indices, non-canonical two-color blocks, output overflow, and CRC mismatch.

## Block commands

| Opcode | Payload | Result |
|---:|---|---|
| 0 | none | same-position block from the previous frame |
| 1 | one-byte block index | named block from the previous frame |
| 2 | one palette index | 64 pixels of one color |
| 3 | low color, high color, 8-byte bitmap | two-color block; bitmap bits select high color |
| 4 | byte count, PackBits bytes | XOR decoded delta with the same-position previous block |
| 5 | 64 bytes | raw block |

Opcodes 0, 1, and 4 are forbidden in keyframes. The encoder evaluates all valid representations
and chooses the shortest, breaking ties by opcode and then encoded bytes so output is reproducible.

The PackBits substream uses controls 0–127 for 1–128 literals, 129–255 for 128–2 repetitions, and
128 as a no-op. It must consume exactly its declared bytes and produce exactly 64 XOR bytes.

## SVX1 whole-frame candidate

The first optimization pass added a separate `SVX1` candidate rather than changing SVC1. Its
packet header is ASCII `SVX1`, one flags byte, a two-byte payload size, and the decoded CRC-16.
Keyframes PackBits-encode the complete raw 4,480-byte frame; delta frames PackBits-encode the
complete bytewise XOR against the previous frame. The same distinct-buffer and refill-callback
rules apply. Decoding must consume exactly the declared payload and produce exactly 4,480 bytes.

SVX1 has no block commands. It trades block-level motion copies and random block decoding for a
smaller format, a simpler decoder, and PackBits runs that can continue across tile boundaries.
The bounded target decoder has a playback entry point that performs every header, length, PackBits,
and output-bound check but skips CRC calculation. Host gates verify every packet CRC; the target
CRC entry point remains available for explicit fixture/provenance checks. Ordinary playback does
not spend eight bit-iterations per output byte re-proving immutable ROM data every frame.

The playback architecture stages one complete packet (observed maximum 3,780 bytes) into a bounded
WRAM buffer through the mapper-aware segment/refill layer, then calls the direct-pointer decoder.
This preserves cross-bank/device testing in refill while avoiding a 65816 function call for every
compressed byte. The callback decoder remains the structural/reference path.

After the checked decoder accepts a packet, immutable playback may call the trusted payload hot
loop. It terminates only at the fixed 4,480-byte frame size and omits redundant per-token source
bounds checks; generation, host round-trip gates, packet CRC, and the checked target entry point
prove those bounds before publication.

## Stream container

`tools/snes-video-pack.py` currently writes each packet preceded by its two-byte packet length.
This simple development container is not part of SVC1. The cartridge packer will replace those
prefixes with generated descriptors and mapper-aware segment lists.

## Current measurement

The real-source comparison is recorded in [the Artemis I benchmark](artemis-codec-benchmark.md).
SVX1 currently beats both SVC1 and the required comparison-only LZSS baseline on size; final
selection still awaits target cycle measurements.
