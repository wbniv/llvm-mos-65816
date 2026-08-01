# SVX2 Animated Video Cartridge

**Date:** 2026-07-31
**Status:** Full 300-frame HiROM cartridge complete; 60 fps optimization and ExHiROM follow-up remain
**Depends on:** `2026-07-31-real-video-codec-corpus.md`
**Feeds:** `2026-07-30-exhirom-video-boundary-test.md`

**Full-reel continuation:** [`2026-07-31-svx2-full-artemis-reel.md`](2026-07-31-svx2-full-artemis-reel.md)

## Goal

Build and publish a real SNES ROM that continuously plays computer-graphics video from the
Artemis camera corpus. The first cartridge is a small, ordinary LoROM integration fixture; it
must prove actual multi-frame SVX2 playback before the same machinery is used for the large
ExHiROM reel.

This is not another decode-throughput microbenchmark. Completion requires visible animation,
correct frame ordering, target-side data movement, stable presentation cadence, and a downloadable
ROM in the gallery.

## Non-goals and source constraint

- Do not use *Duck and Cover* or the animated turtle sequence, now or later.
- Do not use gallery LZSS as the video format. The corpus work established that it is compact but
  too slow for the target cadence; SVX2 is the selected video codec.
- Do not wait for unrelated gallery or ExHiROM work before proving the LoROM player.
- Do not call a held single-frame proof an animated cartridge.

## Proven foundation

- [x] Produce a 300-frame, 80x56, 8-bit indexed computer-graphics corpus with one 224-entry
  BGR555 palette.
- [x] Select SVX2 replacement/copy spans after host round-trip and size comparisons.
- [x] Implement and byte-check the 65816 assembly decoder.
- [x] Stage complete packets from ROM into high WRAM and decode the payload actually located at
  `$7F:2009`.
- [x] Measure the functional FastROM pipeline at 607/648 decodes per 600 VBlanks for the
  median/worst fixtures, clearing 60 fps with a full 4,480-byte output gate.
- [x] Diagnose the incorrect visible proof as an llvm-mos 65816 `MVN` operand-encoding defect,
  fix the MC instruction format, add an opcode regression, rebuild the compiler, and preserve the
  upstreamable change as `patches/llvm-mos/0020-mos-65816-block-move-bank-order.patch`.

## First cartridge architecture

Use a bounded reel of consecutive Artemis frames. Frame zero is an independent keyframe; later
frames are SVX2 deltas. The generated asset contains a palette, packet byte arrays, packet sizes,
flags, decoded CRCs, and a frame table. Start small enough to stay comfortably inside LoROM while
retaining the same packet and playback interfaces needed by ExHiROM.

WRAM contains one 4,480-byte framebuffer and a packet staging area at `$7F:2000`. SVX2 delta
spans advance previous and output positions together, so replacement spans can safely overwrite
the same-position old bytes and copy spans are no-ops in an in-place decode. VRAM retains the
visible frame while WRAM becomes the next one. For every frame:

1. stage the selected packet from ROM into high WRAM using GP-DMA;
2. decode `$7F:2009` into the current framebuffer, referring to the previous framebuffer for a
   delta frame;
3. verify the decoded CRC during the boot validation pass;
4. present the completed framebuffer to Mode 7 VRAM during VBlank;
5. advance the frame index.

The in-place property is SVX2-specific and must not be generalized to codecs with backward motion
references. A loop restart must decode frame zero as a keyframe, so it cannot accidentally depend
on the final frame.

## Presentation contract

- Native source: 80x56 indexed pixels, stored as 70 Mode 7 tiles (4,480 bytes).
- Display: exact full-screen Mode 7 mapping with the corpus palette.
- NTSC milestones: first prove 20 fps (one frame per three VBlanks), then 30 fps (two VBlanks),
  then attempt 60 fps (every VBlank).
- A cadence is accepted only when the entire stage/decode/present path meets it without tearing,
  frame reuse disguised as progress, or silent deadline slips.
- Expose a visible diagnostic state and target-readable counters for decoded frames, presented
  frames, CRC failures, and missed presentation deadlines.

## Implementation steps

- [x] Add a deterministic reel-asset generator that reads consecutive frames from
  `build/real-video-floyd.tiles`, emits independently compilable C data, checks every host decode,
  and reports packet sizes and total ROM use.
- [x] Add the LoROM video-player example with an in-place WRAM framebuffer, high-WRAM packet
  staging, SVX2 keyframe/delta dispatch, and VBlank-paced VRAM DMA.
- [x] Add a boot validation pass that decodes every embedded frame and checks the packet's decoded
  CRC before visible playback begins.
- [x] Add a reproducible build/run script and map-file checks for ROM placement, packet bounds,
  WRAM buffers, FastROM execution, and diagnostic symbols.
- [x] Run the ROM under bsnes-jg long enough to cover multiple complete loops; fail on bad CRC,
  bad sequence, or a missed cadence gate.
- [x] Capture a representative rendered frame and compare it with the host reference, including
  palette and tile ordering rather than relying only on a target-side CRC.
- [x] Establish 20 fps, then establish 30 fps with **482 exact presentations and zero deadline
  slips in 1,200 VBlanks** after boot validation. The first 60 fps attempt misses 160 deadlines in
  the same window, so the verified/default cartridge remains 30 fps pending further optimization.
- [x] Publish the verified `.sfc` and gallery player entry, with codec, dimensions, cadence,
  frame count, source attribution, checksum, and an explicit fidelity-verification result.
- [x] Reuse the same player/stream boundary for the complete 300-frame HiROM reel.
- [ ] Exercise the same boundary logic across the separate 4 MiB ExHiROM boundary fixture.

## Verification gates

The LoROM cartridge is complete only when all of the following pass:

1. every generated packet round-trips on the host;
2. every embedded frame passes target-side decoded CRC validation;
3. the first visible frame matches the host raster and palette;
4. at least two full playback loops preserve order and keyframe reset behavior;
5. the measured presentation count matches the selected VBlank cadence with zero slips;
6. the ROM header and checksum are valid and the ROM boots from a clean emulator state;
7. the exact verified ROM is the file published in the gallery.

## Upstream compiler follow-up

Keep the compiler correction distinct from the demo publication. Before submitting upstream:

- reduce the `MVN`/`MVP` failure to the MC opcode test;
- confirm syntax and encoded byte order against WDC documentation and accepted llvm-mos assembly
  conventions;
- run the focused MC test and the relevant llvm-mos test suite;
- prepare a minimal commit/PR containing the TableGen fix and regression only; and
- reference the animated ROM as the real-world reproducer, without coupling the upstream patch to
  this repository's video assets.

## Deliverables

- generated bounded-reel asset tooling;
- animated LoROM player source and reproducible build command;
- automated target correctness/cadence results;
- a verified downloadable `.sfc` in the gallery; and
- a minimal upstream-ready llvm-mos `MVN`/`MVP` fix.

## Implementation record

Completed 2026-07-31:

- four consecutive Artemis press-site camera frames, one keyframe plus three SVX2 deltas;
- 3,433 compressed packet bytes, maximum packet 950 bytes, in a 32 KiB FastROM LoROM;
- host round-trip generation, target CRC validation, keyframe loop reset, and two-loop gate;
- NMI-counted 30 fps scheduler: 482 presentations in 1,200 VBlanks after boot validation, zero
  CRC failures, and zero deadline slips;
- attempted 60 fps scheduler: 160 missed deadlines in 1,200 VBlanks, correctly rejected;
- emulator/host screenshot gate: 90.3163% exact pixels and 2.0916 mean absolute channel error
  after the Mode 7 scaling path;
- ROM SHA-256 `825e3848917c669481c6da1eac6212d857aa1c399d6a1c2ffba8d264d0708c99`;
  and
- gallery commit `bd102e8`, release tag `v1.0.317`, with its 1,200-frame live self-check passing.

Full-reel continuation completed 2026-07-31:

- all 300 approved Artemis frames in a 765,503-byte packed SVX2 stream;
- 1 MiB Fast HiROM with 16-bit frame indexing and DMA split at 64 KiB ROM-bank boundaries;
- complete host round trip plus target CRCs for every bank-crossing packet and the reset keyframe;
- 716 exact presentations in 2,400 VBlanks, over two complete loops, with zero decoder errors and
  zero deadline slips; and
- frame-115 emulator/host visual gate passes with the corrected Mode 7 dashboard split model.

The integration also exposed a second staged-keyframe defect: the parser selected DBR `$7F` for
high-WRAM token reads, but ordinary indirect run stores and absolute parser-state loads then used
that same bank. The corrected kernel keeps DBR at `$00` and uses explicit long `$7F` reads for
staged token/payload bytes. The existing staged-delta 607/648-per-600 regression and all 17 host
codec tests still pass.
