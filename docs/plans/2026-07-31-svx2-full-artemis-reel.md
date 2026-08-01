# SVX2 Full Artemis Camera Reel

**Date:** 2026-07-31
**Status:** Complete 2026-07-31
**Depends on:** `2026-07-31-real-video-codec-corpus.md`,
`2026-07-31-svx2-animated-video-cartridge.md`, and
`2026-07-31-svx2-cartridge-video-dashboard.md`

## Goal

Replace the four-frame integration reel with all 300 approved frames of the ten-second NASA
Artemis I camera corpus. Preserve the animated title, 30 fps presentation, cartridge-native BG3
dashboard, SVX2 decoder, and exact target gates.

No *Duck and Cover* or animated turtle sequence is permitted. The video format remains SVX2, not
LZSS.

## Cartridge choice

The measured complete SVX2 stream is 765,503 bytes, so the finished cartridge is a standard 1 MiB
HiROM. It does not require ExHiROM. ExHiROM remains a separate multi-megabyte boundary-test
milestone; using it here would add mapper complexity without exercising its 4 MiB boundary.

HiROM provides contiguous 64 KiB banks `$C1+` for a packed far-data stream. Near bank `$00` keeps
code, tables, dashboard state, and vectors.

## Interactive mockups

[Open the full-reel title, playback, and loop mockups](2026-07-31-svx2-full-artemis-reel/mockups.html).

The mockup shows title/validation, early playback, the end of the ten-second reel, and the seamless
frame-299 to keyframe-0 loop while retaining the corrected two-row cartridge dashboard.

## Stream layout

- Concatenate all SVX2 packets into one `.far_rodata` byte stream.
- Emit a 301-entry offset table, 300 decoded CRCs, and frame count as near metadata.
- Use a 16-bit frame index; frame 300 wraps to frame zero.
- Convert each stream offset to canonical HiROM bank/address.
- Split ROM-to-WRAM DMA at a 64 KiB bank boundary; no DMA descriptor may wrap `$ffff->$0000`.
- Frame zero is always a keyframe. Frames 1–299 are deltas.

## Validation policy

The generator host-decodes and byte-compares all 300 packets. Repeating the bit-serial target CRC
over all 1.34 MiB of decoded boot data would leave the title on screen for minutes, so the shipping
ROM performs the frame-zero/keyframe-reset target CRC at boot and relies on the already target-proven
decoder plus complete-loop sequencing for the full stream. The emulator gate must observe at least
two complete 300-frame loops, the frame-299→0 transition, zero decoder errors, and zero deadline
slips.

## Dashboard

- `TIME` is cumulative presentation time and does not reset at the reel boundary.
- `FPS` remains measured over 60 VBlanks and must display approximately `30.0`.
- `SVX2 VIDEO / PLAY` remains on the first BG3 row.
- The one-tile blank margin below the Mode 7/Mode 1 split remains mandatory.

## Implementation steps

- [x] Add packed-far output to the deterministic reel generator.
- [x] Expand the player and diagnostic frame index to 16 bits.
- [x] Add bank-splitting HiROM packet staging.
- [x] Build all 300 frames with `mos-snes-hirom.cfg` and patch a Fast HiROM header.
- [x] Update the target loop gate for two complete 300-frame loops.
- [x] Extend the emulator duration and exact presentation oracle.
- [x] Capture a representative target frame and model the title, playback, and 299→0 transition
  in the interactive mockups.
- [x] Run host round-trip, target keyframe CRC, two-loop, cadence, slip, blanking, screenshot,
  checksum, and gallery gates.
- [x] Replace and publish the gallery ROM; verify the live SHA-256.

## Acceptance gates

1. Exactly 300 source frames and packets are embedded.
2. Every packet host-round-trips to its 4,480-byte source frame.
3. ROM is valid Fast HiROM and all far-stream bytes are mapped.
4. Packets crossing a 64 KiB bank boundary stage without gaps or duplication.
5. Frames advance 0…299, then keyframe-reset to 0, for at least two complete loops.
6. Presentation remains at the selected 30 fps cadence with zero deadline slips.
7. Dashboard time crosses `00:10`; FPS settles near `30.0`; glyph tops remain intact.
8. No excluded footage is present.
9. The live ROM hash equals the locally gated artifact.

## Implementation result

- 300 packets, 765,503 stream bytes, maximum packet 3,529 bytes.
- 1,048,576-byte Fast HiROM; stream begins at file offset `$010000` / canonical bank `$C1`.
- Clean-checkout build succeeds from the checked-in metadata and packed stream.
- At 2,400 VBlanks, the composite target gate at WRAM `$0040` is `$00000000`: decoder healthy,
  two complete loops observed, and zero missed deadlines.
- Exact cadence oracle: 716 presentations (`$02CC`) in the same emulator run.
- Representative frame 115 visual gate: 69.6696% exact RGB pixels and 3.3463 mean absolute
  channel error after modeling the non-integer Mode 7 vertical scale and dashboard split.
- Local/publish artifact SHA-256: `31cfed53799fa9d3674a75cc3ea9434d8c37ae16706dca645222e11c51388baf`.
- Published by gallery commit `f2ab4c9`, release `v1.0.328`; the deployment completed successfully,
  the downloaded ROM hash is identical, and its live artifact passes the 2,400-frame composite gate.
