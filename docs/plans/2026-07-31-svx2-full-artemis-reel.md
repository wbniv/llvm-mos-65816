# SVX2 Two-Video Artemis Reel

**Date:** 2026-07-31
**Status:** Shared-palette dashboard correction published and live-verified 2026-08-01
**Depends on:** `2026-07-31-real-video-codec-corpus.md`,
`2026-07-31-svx2-animated-video-cartridge.md`, and
`2026-07-31-svx2-cartridge-video-dashboard.md`

## Goal

Publish both approved corpora in one continuous cartridge: 600 frames / 20 seconds of NASA SVS
Artemis launch-and-return animation, followed by 300 frames / 10 seconds of real Artemis I launch
camera footage. Preserve the animated title, 30 fps presentation, cartridge-native BG3 dashboard,
SVX2 decoder, and exact target gates.

No *Duck and Cover* or animated turtle sequence is permitted. The video format remains SVX2, not
LZSS.

## Cartridge choice

The measured combined SVX2 stream is 2,311,832 bytes, so the finished cartridge is a standard
4 MiB HiROM. It does not require ExHiROM.

HiROM provides contiguous 64 KiB banks `$C1+` for a packed far-data stream. Near bank `$00` keeps
code, tables, dashboard state, and vectors.

## Interactive mockups

[Open the full-reel title, playback, and loop mockups](2026-07-31-svx2-full-artemis-reel/mockups.html).

The mockup covers the animation launch/return video, the independent-keyframe cut to real camera
footage at frame 600, and the frame-899 to frame-0 loop while retaining the dashboard.

## Stream layout

- Concatenate all SVX2 packets into one `.far_rodata` byte stream.
- Emit a 901-entry offset table, 900 decoded CRCs, one shared shipping palette, and the frame-600
  cut as metadata.
- Use a 16-bit frame index; frame 900 wraps to frame zero.
- Convert each stream offset to canonical HiROM bank/address.
- Split ROM-to-WRAM DMA at a 64 KiB bank boundary; no DMA descriptor may wrap `$ffff->$0000`.
- Frames 0 and 600 are independent keyframes; each video therefore resets codec state without a
  runtime CGRAM transition.

## Validation policy

The generator host-decodes and byte-compares all 900 packets. Exhaustive target CRC work remains in
the build gate; the shipping ROM exercises both independent keyframes behind a short title and
begins playback before emulator frame 240. The emulator gate observes at least two complete
900-frame loops, the independent frame-600 keyframe, zero decoder errors, and zero deadline slips.

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

1. Exactly 900 source frames and packets are embedded: 600 animation and 300 real camera.
2. Every packet host-round-trips to its 4,480-byte source frame.
3. ROM is valid Fast HiROM and all far-stream bytes are mapped.
4. Packets crossing a 64 KiB bank boundary stage without gaps or duplication.
5. Frames advance 0…899 and reset codec state at 600 and 0 for at least two complete loops.
6. Presentation remains at the selected 30 fps cadence with zero deadline slips.
7. Dashboard time crosses `00:30`; FPS settles near `30.0`; glyph tops remain intact.
8. No excluded footage is present.
9. The live ROM hash equals the locally gated artifact.

## Implementation result

- Superseded first publication: 300 packets / one real-camera video only.
- Corrected build: 900 packets, 2,311,832 stream bytes, maximum packet 3,812 bytes.
- 4,194,304-byte Fast HiROM; stream begins at file offset `$010000` / canonical bank `$C1`.
- Clean-checkout build succeeds from the checked-in metadata and packed stream.
- At 4,000 VBlanks, the composite target gate at WRAM `$0040` is `$00000000`: decoder healthy,
  two complete loops observed, and zero missed deadlines.
- Exact cadence oracle: 1,909 presentations (`$0775`) after 4,000 VBlanks.
- Representative frame 115 visual gate: 69.6696% exact RGB pixels and 3.3463 mean absolute
  channel error after modeling the non-integer Mode 7 vertical scale and dashboard split.
- Superseded one-video artifact: release `v1.0.328`, SHA-256 `31cfed53799fa9d3674a75cc3ea9434d8c37ae16706dca645222e11c51388baf`.
- Corrected two-video artifact SHA-256:
  `488f03001919f3c83006b13c39bc99dee8563886e88e21a07d564c0ff68b5af3`.
- Published by gallery commit `d9dd125`, release `v1.0.329`; deployment succeeded, the downloaded
  4 MiB ROM hash is identical, and that live artifact passes the 6,500-frame composite gate.
- Fast-start correction removes the roughly 42-second boot-time stream walk. Corrected artifact
  SHA-256: `ca22da27741b1c9533811580245cc61bb57f147b07076230fbc86d9101e2212c`.
- Gallery commit `e344090`, release `v1.0.330`; deployment succeeded, the downloaded hash matches,
  and the live artifact passes the 4,000-frame composite gate.
- The first fast-start build lost the dashboard after palette changes because runtime CGRAM DMA
  destabilized the active HDMA split. Force blank avoided corruption but introduced visible black
  frames, so the final reel instead learns one shared 223-color palette across both corpora. It
  performs no runtime palette upload while retaining independent keyframes at frames 0 and 600.
  Separate animation and real-camera screenshot gates require dashboard ink, and the 4,000-frame
  blank-scan gate rejects any transient full-screen blanking. Corrected SHA-256:
  `fc1890860d75c01e598cf315e7a9d9814ea51905ed76ac048d4ccff72ebcdee4`.
- Main implementation commit `79bb73b`; gallery commit `c556890`; release `v1.0.335`.
  Deployment succeeded, the downloaded live ROM has the same SHA-256, and the live artifact passes
  the 4,000-frame composite (`$00000000`) and exact cadence (`$0775`) gates.
