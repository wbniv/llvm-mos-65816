# SVX2 60 FPS Full-Pipeline Plan

**Date:** 2026-08-01
**Status:** 60-packet/s full pipeline proved; true 60 fps source and endurance remain
**Depends on:** `2026-07-31-svx2-animated-video-cartridge.md`, `2026-07-31-real-video-codec-corpus.md`
**Preserves:** the verified 30 fps player as the shipping fallback

## Goal

Make the complete SNES video path sustain **60 unique decoded and presented frames per second**:
FastROM packet access, WRAM staging, SVX2 decode, VRAM upload, dashboard maintenance, input,
and scheduling. Acceptance requires the full two-video workload to run without hidden repeats,
tearing, corruption, or missed presentation deadlines.

This plan distinguishes three claims that must not be conflated:

| Claim | Meaning | Current state |
|---|---|---|
| 60 Hz display | The PPU scans the retained VRAM image every VBlank | Inherent |
| 60 presentations/s | The player schedules a presentation every VBlank | Prior attempt missed 160/1,200 deadlines |
| 60 unique frames/s | Each VBlank receives the next distinct 59.94/60 fps source frame | Not yet proved; current masters are 30 fps |

Repeating each 30 fps source frame twice is a useful scheduler test, but it is not the final
60 fps result and should not perform a redundant second VRAM upload.

## Constraints and non-goals

- Continue using SVX2. Do not substitute gallery LZSS for the video codec.
- Never use *Duck and Cover* or its animated turtle sequence.
- Preserve the existing 30 fps ROM and build mode until the 60 fps gates pass.
- Do not weaken fidelity, frame order, transport controls, title sequence, or dashboard behavior
  merely to improve a counter.
- Seek keyframes may take multiple VBlanks while paused; continuous playback deadlines are the
  hard real-time requirement.
- Do not introduce a new stream format until measurements show the current SVX2 representation is
  the limiting component.

## Known baseline

- A functional FastROM staged microbenchmark completed 607/648 median/worst-fixture decodes per
  600 VBlanks with a full 4,480-byte output gate. That proves feasibility, but leaves little
  margin and does not include every player cost.
- The first integrated 60 fps attempt missed 160 deadlines over 1,200 VBlanks; verified playback
  therefore remained at 30 fps.
- The shipping reel is 900 frames: 600 NASA animation frames and 300 approved real-camera frames.
- A visible frame is 4,480 bytes: 70 Mode 7 tiles of 64 bytes each.
- The current player already overlaps work conceptually: stage and decode outside VBlank, then
  present during VBlank. The next work must quantify where that schedule loses time.

**Implementation/profile record:**
[`2026-08-01-svx2-60-fps-pipeline-profile.md`](../investigations/2026-08-01-svx2-60-fps-pipeline-profile.md)

## Frame budget

At NTSC cadence the complete path has about 16.68 ms per frame. The design target is no more than
15.0 ms worst-case for stage, decode, bookkeeping, and the required VBlank upload, leaving roughly
10% guard time for packet variance, interrupts, input, and HUD work.

```text
one 16.68 ms interval
| active display: stage packet -> decode -> prepare upload | VBlank: video DMA -> HUD DMA |
|---------------- work for frame N+1 ----------------------|------ present frame N+1 ------|
```

The dashboard and automatic joypad results are consumers of the budget, not exceptions to it.
Input must be sampled after the automatic latch completes without busy-waiting on the decode path.

## Phase 0 — measure the actual 900-frame pipeline

- [x] Add target-readable timestamps/counters around packet staging, decode, presentation DMA,
  HUD update, input handling, and idle time.
- [ ] Record per-frame packet size, token counts, changed bytes/tiles, bank crossings, phase cost,
  and whether the deadline was met.
- [x] Run all 900 frames, not only the median and selected worst fixtures; report maximum and
  p50/p95/p99 phase costs and identify the exact missed packets.
- [ ] Add a host report that correlates target timing with packet structure so an optimization can
  be evaluated against the corpus rather than anecdotes.
- [ ] Measure with the HUD static and changing, input idle and active, and across both video
  boundaries and loop reset.

**Exit gate:** a reproducible budget report accounts for every missed VBlank and identifies whether
ROM staging, decode, VRAM upload, or ancillary work is the dominant limit.

## Phase 1 — remove scheduling and ancillary overhead

- [x] Keep packet staging and decode entirely in active display time; reserve VBlank for VRAM DMA
  and the smallest necessary PPU/HUD register work.
- [x] Use automatic joypad latching everywhere and consume `$4218/$4219` only after completion;
  do not serially poll `$4016` or stall the critical path.
- [ ] Shadow dashboard state in WRAM and upload only changed cells, after video DMA. Reduce the
  time/FPS refresh rate if necessary while preserving accurate displayed values.
- [ ] Precompute frame table fields needed by the hot loop, including packet address, size, flags,
  and bank-split information, so presentation does no generic parsing.
- [ ] Double-buffer packet staging metadata (and data if measurements justify it) so address setup
  for frame N+1 cannot delay presentation of frame N.
- [x] Make the cadence scheduler explicit: a frame is either ready before its VBlank or a recorded
  deadline failure; never silently repeat it and increment the presentation count.

**Exit gate:** the full integrated player clears 600 scheduled intervals with zero logical repeats,
and the report shows at least 10% worst-case headroom or names the remaining hot phase.

## Phase 2 — reduce VRAM traffic with changed-tile runs

The framebuffer is tile-major, so encoder-side analysis can determine which of the 70 tiles differ
from the preceding frame. Preserve the normal SVX2 bitstream initially and emit presentation
metadata alongside it:

- [ ] Generate a 70-bit changed-tile mask and coalesce adjacent changed tiles into DMA runs.
- [ ] Upload only changed 64-byte tile runs; keyframes and scene cuts retain a full-frame upload.
- [ ] Account for DMA setup cost so sparse runs are combined when setup costs more than extra data.
- [ ] Verify that skipped VRAM tiles retain the exact preceding contents and that Mode 7 tilemap,
  palette, and dashboard regions are never touched.
- [ ] Measure the full corpus distribution. Keep full-frame DMA for packets where sparse upload is
  not cheaper.

**Exit gate:** pixel-exact host/emulator comparison passes on sparse deltas, dense motion, keyframes,
scene transitions, and loop reset; worst-case presentation still completes before active display.

## Phase 3 — optimize SVX2 only if decode remains limiting

- [ ] Rank token forms and decoder branches by target cost and corpus frequency.
- [ ] Specialize the 65816 hot loop for the common copy/replacement lengths while retaining a
  checked generic path.
- [ ] Hoist invariant bank and pointer setup out of token processing.
- [x] Skip previous-copy `MVN` spans when previous and output are the same in-place framebuffer;
  preserve the general copy path for distinct buffers.
- [ ] Compare staged-WRAM decoding with direct FastROM reads using the complete phase cost, not
  decode time alone.
- [ ] If format evolution is justified, prototype it as a versioned successor with host round-trip
  tests and side-by-side size/cycle results. Do not call it SVX2 if it is incompatible.

**Exit gate:** every one of the 900 packet shapes completes within budget with measured guard time;
all existing SVX2 host and target regressions remain green.

## Phase 4 — prove genuinely unique 60 fps content

- [ ] Add a deterministic 59.94/60 fps source set with genuinely distinct consecutive frames and
  acceptable provenance; do not create the final claim by duplicating 30 fps frames.
- [ ] First use duplicated/interpolated indices only as a pipeline stress fixture, clearly labeled
  non-final.
- [ ] Generate a 60 fps reel, validate every packet on the host, and preserve independent keyframes
  at video/seek boundaries.
- [ ] Add a target-visible monotonically changing frame identity and a gate that rejects duplicates,
  skips, reordering, and counter-only progress.
- [ ] Keep a build-time 30 fps mode using the same player so regression comparisons remain direct.

**Exit gate:** at least 9,000 consecutive scheduled frames (ten current-reel lengths) present in
order at NTSC cadence with zero unintended duplicates, skips, CRC errors, or deadline slips.

## Phase 5 — integration, transport, and publication

- [ ] Verify pause, resume, single-frame step, ±1-second seek, and 2x/4x/8x shuttle. Exclude
  intentional pause/seek intervals from cadence accounting, then require exact recovery.
- [ ] Keep the transport overlay and time/FPS dashboard visible and correct at 60 fps without
  reducing video correctness.
- [ ] Run the blank-scan/composite-health gate to prove DMA never leaks into visible video.
- [ ] Compare representative target captures against host rasters for both videos, including
  motion-heavy and sparse frames.
- [ ] Publish only the exact ROM that passed the exhaustive gate; record its checksum, source-frame
  cadence, unique-frame count, timing distribution, and emulator/browser verification.
- [ ] Retain the verified 30 fps artifact as fallback until the published 60 fps ROM passes its
  live gallery check.

## Required automated gates

1. Host round-trip for every regular packet and seek keyframe.
2. Target CRC coverage for keyframes, bank crossings, dense deltas, and loop reset.
3. Exact cadence window: 600 distinct presentations in 600 eligible VBlanks, then a 9,000-frame
   endurance run with zero misses.
4. A frame-identity trace proving no disguised duplication, skipping, or reordering.
5. Phase timing maximum and p99 below the declared budget with at least 10% worst-case margin.
6. Pixel fidelity and blank-scan checks with dashboard and transport enabled.
7. Controller replay covering playback, pause, step, seek, shuttle, and resume.
8. Exact published-ROM checksum and live gallery playback verification.

## Decision points

| Measurement | Next action |
|---|---|
| Stage dominates | Precompute bank splits; compare double buffering and direct FastROM reads |
| Decode dominates | Specialize common SVX2 token paths; consider a versioned format only with evidence |
| VRAM DMA dominates | Ship adaptive changed-tile DMA runs with full-frame fallback |
| HUD/input dominates | Defer and batch HUD DMA; fix latch scheduling without removing controls |
| Worst case lacks 10% margin | Do not publish 60 fps; keep 30 fps and continue optimization |

## Deliverables

- a reproducible full-corpus phase-timing report;
- adaptive presentation metadata and target implementation if justified by measurements;
- a true 59.94/60 fps, uniquely framed test reel with provenance;
- exhaustive correctness, cadence, fidelity, input, and endurance gates;
- a verified 60 fps `.sfc` plus retained 30 fps fallback; and
- updated hardware/programming documentation describing the measured scheduling and DMA limits.
