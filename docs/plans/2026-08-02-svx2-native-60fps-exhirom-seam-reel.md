# SVX2 native-60-fps ExHiROM seam reel

**Date:** 2026-08-02
**Status:** Complete — native-60 ExHiROM artifact gated and published as v1.0.356
**Extends:** [SVX2 60 fps full pipeline](2026-08-01-svx2-60-fps-full-pipeline.md)

## Outcome

Publish a 64-Mbit (8 MiB) Fast ExHiROM SVX2 cartridge that plays 1,800 genuinely
distinct, native-60-fps source frames in 30 seconds. The cartridge must make the expanded
ROM useful as a stress test: executable code runs through a FastROM mirror, video packets
cross the 32-Mbit ExHiROM region seam, seeking crosses the same mapping, and a multi-loop
target gate proves that no bank transition corrupts decode or presentation.

The prior 900-packet cartridge remains evidence that the player can schedule one packet per
VBlank, but it is not evidence of correct source speed. The derived 1,800-frame artifact is
also only a throughput/layout fixture because its masters were authored at 30 fps. Neither may
be presented as the final 60-fps result.

## Source and presentation

Use [NASA Scientific Visualization Studio item 20374](https://svs.gsfc.nasa.gov/20374/),
**XRISM Beauty Shots**, specifically
`XRISM_360_4k_60fps_h264.mp4`. NASA publishes this master as 3840×2160, 60 fps. Vendor the
exact source and record its digest.

Construct three ten-second excerpts from native frames 0–599, 1200–1799, and 2400–2999.
This gives the dashboard meaningful cut changes while keeping every output frame sourced from
a distinct native temporal sample:

| Reel frames | Source frames | Dashboard label |
|---:|---:|---|
| 0–599 | 0–599 | `XRISM / ORBIT` |
| 600–1199 | 1200–1799 | `XRISM / RESOLVE` |
| 1200–1799 | 2400–2999 | `XRISM / XTEND` |

Convert each selected frame directly to the 80×45 picture inside the 80×56 SNES raster. Do
not duplicate, interpolate, or retime a 30-fps source. Learn one deterministic 223-colour
222-colour content palette across the complete reel, reserve entries 0/1 for dashboard
black/white, and
encode the resulting tile-major frames with SVX2.

## Diagnosed ExHiROM failure

The first 64-Mbit build had two coupled layout defects:

1. generated stream metadata described ordinary HiROM banking even though the packer inserted
   an ExHiROM hole at file `$400000-$40ffff`; and
2. `video_reel_enter_fast` changed PBR from bank `$00` to bank `$80`. That is a valid mirror
   for ordinary HiROM, but ExHiROM bank `$80` selects file region A, which contained compressed
   video. The CPU therefore jumped into packet bytes before player initialization.

The decoder was not responsible. The black screen and zero-looking health word occurred because
the executable was never entered.

## Cartridge layout

Reserve one physical bank at the beginning of region A for a FastROM mirror of the linked
bank-`$40` near/boot window:

```text
file $000000-$00ffff   CPU $c0:0000-$ffff   mirrored near code (FastROM execution)
file $010000-$3fffff   CPU $c1:0000-$ff:ffff SVX2 stream part A (4,128,768 bytes)
file $400000-$40ffff   CPU $40:0000-$ffff   canonical boot, code, header, vectors
file $410000-$7dffff   CPU $41:0000-$7d:ffff SVX2 stream continuation
file $7e0000-$7e7fff   unreachable ExHiROM hole
file $7e8000-$7effff   CPU $3e:8000-$ffff
file $7f0000-$7f7fff   unreachable ExHiROM hole
file $7f8000-$7fffff   CPU $3f:8000-$ffff
```

The FastROM trampoline targets `$c0`, not `$80`. Logical stream offset zero maps to file
`$010000` / bank `$c1`. Logical offset `$3f0000` maps to file `$410000` / bank `$41`.
Because both discontinuities are 64-KiB aligned, packet address low words remain unchanged;
only bank selection changes.

## Implementation

- [x] Make the RGB24 conversion command accept an explicit source rate and exact frame count.
- [x] Add a reproducible native-60 reel build that selects the three source intervals, emits
  RGB24, learns the shared palette, and generates tile-major frames.
- [x] Change the FastROM trampoline from bank `$80` to bank `$c0`, which remains valid for
  ordinary HiROM and reaches the reserved mirror in ExHiROM.
- [x] Reserve file bank 0 for mirrored near code in the ExHiROM packer.
- [x] Start ExHiROM stream data at file `$010000` / bank `$c1`.
- [x] Change the region-A/region-B logical seam from `$400000` to `$3f0000`.
- [x] Add packer assertions that the linked near window exists, the mirror does not overlap
  stream bytes, and every output extent is within the 8-MiB image.
- [x] Emit cut labels and 60-frame seek keyframes for the final 1,800-frame reel.
- [x] Record the physical location of packets immediately before, across, and after the seam:
  frame 1199 starts at `$3efcdb`, frame 1200 at `$3f0000`, and frame 1201 at `$3f04d8`.

## Required gates

### Source and host gates

- [x] `ffprobe` reports `r_frame_rate=60/1`, `avg_frame_rate=60/1`, and sufficient source frames.
- [x] The selected source-frame indices contain exactly 1,800 entries with no repeated index.
- [x] The quantized corpus contains 1,800 unique frames and zero adjacent identical frames.
- [x] Every regular packet, seek keyframe, and loop delta round-trips byte-exactly on the host.
- [x] The packed stream plus code reservation fits the reachable ExHiROM extents.
- [x] Header, vectors, map mode `$35`, 64-Mbit size byte, checksum, and complement inspect cleanly.

### Target and seam gates

- [x] Boot reaches initialized player state through the `$c0` FastROM mirror.
- [x] Rendezvous at frame 700 succeeds in stream region A.
- [x] Rendezvous at frame 1750 succeeds after the logical `$3f0000` seam into region B.
- [x] Exact framebuffer checks pass immediately before and after the packet that crosses the seam.
- [x] Seek backward and forward across the seam, then resume without CRC, order, or cadence error.
- [x] Two complete loops produce composite health zero.
- [x] A 9,000-presentation endurance run produces zero deadline slips, CRC failures, reordering,
  unintended duplication, or skipped presentation.
  The exact rendezvous is emulator field 9,177: 177 title fields plus 9,000 presentations.
  It completed with presentation counter `$2328`, composite health zero, and deadline slips zero.
- [x] Representative screenshots match the host raster and keep the dashboard uncorrupted.

### Publication gates

- [x] Dashboard time advances from `00:00.0` through `00:29.9` and resets on the loop.
- [x] Dashboard reports `FPS 60.0` and changes the source label at both cuts.
- [x] Pause/resume, step, ±1-second seek, and shuttle controls recover exact playback order.
- [x] The gallery describes the cartridge as **64 Mbit (8 MiB) Fast ExHiROM**, 1,800 frames,
  native 60 fps, 30 seconds, and names the three source excerpts.
- [x] Publish the exact gated ROM, verify its live SHA-256, and record release **v1.0.356**:
  `6a4d176be0683bbb135872820e5db65ed2ef1b97d7b911149a64a43c8c28af24`.

## Acceptance

This plan is complete only when the public ROM plays the native-60 reel at its authored speed,
the 1,800 SNES frames are all distinct after quantization, the source and generated artifacts are
reproducible, and the expanded-ROM seam is exercised by both sequential playback and transport
without corruption. A 30-fps master, doubled frames, optical-flow interpolation, or merely a
60-packet/s counter does not satisfy acceptance.
