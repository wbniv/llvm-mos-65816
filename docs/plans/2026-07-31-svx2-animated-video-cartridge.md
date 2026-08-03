# SVX2 Animated Video Cartridge

**Date:** 2026-07-31
**Status:** Full two-video 900-frame HiROM cartridge complete; 60 fps optimization and ExHiROM follow-up remain
**Depends on:** `2026-07-31-real-video-codec-corpus.md`
**Feeds:** `2026-07-30-exhirom-video-boundary-test.md`

**Full-reel continuation:** [`2026-07-31-svx2-full-artemis-reel.md`](2026-07-31-svx2-full-artemis-reel.md)

**60 fps continuation:** [`2026-08-01-svx2-60-fps-full-pipeline.md`](2026-08-01-svx2-60-fps-full-pipeline.md)

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

## Verification record — 2026-08-03, against `main` @ `1feca62`

The seven gates above are stated as outcomes, not as commands, so each step below names the
command chosen to produce its evidence. The gate text itself is reproduced verbatim and
unreordered. Toolchain used as-built (`build/llvm-mos-install/bin/mos-clang`, `build/jgxcheck`);
no rebuild.

**Preliminary — the LoROM first cartridge no longer builds on `main`.** Gates 1–6 speak of "the
LoROM cartridge". Reproducing that configuration is the first thing attempted, and it fails:

```
$ VIDEO_REEL_FRAMES=4 VIDEO_REEL_FIRST_FRAMES=0 dev/snes-video-reel.sh
frames=4 packets=2877 seek=0 loop=828 padding=0 total=3705 max=897
/home/will/llvm-mos-65816/examples/snes/snes-video-reel.c:287:20: error: use of undeclared identifier 'VIDEO_REEL_HIROM_BASE_BANK'
  287 |   return (uint8_t)(VIDEO_REEL_HIROM_BASE_BANK + (uint8_t)(offset >> 16));
      |                    ^~~~~~~~~~~~~~~~~~~~~~~~~~
1 error generated.
```

`tools/snes-video-reel-assets.py` emits `VIDEO_REEL_HIROM_BASE_BANK` only on the `--packed-far`
(>4-frame) path, while `snes-video-reel.c:287` references it unconditionally. Suspected commit:
`bd344a1` "snes: ship complete 300-frame SVX2 reel" (the `-S` history for that symbol is
`bd344a1` → `21179d7` → `d6030cf`). **FAIL.** Gates 1–6 below are therefore run against the
plan's *delivered* configuration — the full two-video 900-frame Fast HiROM cartridge of the
"Full two-video continuation" implementation record, which is what the checked-in asset header
(`VIDEO_REEL_FRAME_COUNT 900u`, `VIDEO_REEL_SECOND_START 600u`) and the default
`dev/snes-video-reel.sh` invocation now describe.

### 1. every generated packet round-trips on the host;

Command: `dev/snes-video-reel.sh` (asset generator leg — `tools/snes-video-reel-assets.py`
host-decodes and CRC-checks every packet it emits), plus the host codec unit suite.

```
$ dev/snes-video-reel.sh
frames=900 packets=2314741 seek=82651 loop=3750 padding=0 total=2401142 max=3812
packed 2401142 stream bytes at file $010000; ROM=4194304 bytes
```

```
$ python3 -m pytest tests/test_snes_video_codec.py -q
........................                                                 [100%]
24 passed in 1.74s
```

**PASS** — generation is non-fatal (the generator aborts on any host round-trip mismatch) and the
24-test host codec suite is green.

### 2. every embedded frame passes target-side decoded CRC validation;

Command: the composite-health gate inside `dev/snes-video-reel.sh` —
`build/jgxcheck <rom> <db> 0x207 4 00000000 4000`. `video_reel_composite_health` becomes zero
only after boot validation and two loops with no result, CRC, or deadline failure.

```
SMOKE: PASS off=0x207 len=4 got=0x00000000 (ran 4000 frames, bsnes-jg)
```

**PASS** — zero CRC failures across the boot validation pass and 4,000 VBlanks.

### 3. the first visible frame matches the host raster and palette;

Command: the screenshot rendezvous + `tools/snes-video-screenshot-check.py` legs of
`dev/snes-video-reel.sh` (bsnes-jg framebuffer PNG compared against the host-quantized tiles and
the shipping palette, with a dashboard-ink assertion).

```
jgxcheck: JGX_POLL matched at frame 395 of 4000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816/build/svx2-video-reel.png (256x224 from native 512x240, yoff=0)
DASHBOARD: PASS ink_pixels=495
FIDELITY: PASS frame=108 exact=47.9248% mae=10.3196
jgxcheck: JGX_POLL matched at frame 1579 of 3000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816/build/svx2-video-reel-transition.png (256x224 from native 512x240, yoff=0)
DASHBOARD: PASS ink_pixels=524
FIDELITY: PASS frame=100 exact=78.3040% mae=2.6257
```

**PASS** — with one recorded drift: the gate now rendezvouses on stream frame 108 (and 100 across
the real-video transition) rather than frame 0, because the animated title card added by
`21179d7` / `d6030cf` precedes playback. The plan's own recorded figure (90.3163% exact /
2.0916 MAE) belonged to the retired 4-frame LoROM cartridge and is not comparable.

### 4. at least two full playback loops preserve order and keyframe reset behavior;

Command: `dev/snes-video-reel.sh` runs the whole gate for 4,000 VBlanks at cadence 2 — 1,911
presentations over a 900-frame reel, i.e. two complete loops plus the keyframe reset between
them. `video_reel_loop_gate` is folded into the composite-health word asserted in step 2, and
the two dashboard cut rendezvous prove segment ordering inside each loop.

```
jgxcheck: JGX_POLL matched at frame 799 of 4000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816/build/svx2-video-reel-cut-one.png (256x224 from native 512x240, yoff=0)
jgxcheck: JGX_POLL matched at frame 1399 of 4000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816/build/svx2-video-reel-cut-two.png (256x224 from native 512x240, yoff=0)
SMOKE: PASS off=0x2D len=2 got=0x02BC (ran 3000 frames, bsnes-jg)
SMOKE: PASS off=0x207 len=4 got=0x00000000 (ran 4000 frames, bsnes-jg)
```

**PASS.**

### 5. the measured presentation count matches the selected VBlank cadence with zero slips;

Command: the cadence gate and the displayed-FPS gauge assertions inside `dev/snes-video-reel.sh`
(`video_reel_presented_total` == `0x777` at VBlank 4,000; `video_fps_tenths` == 300 at VBlank 400
and 4,000). `video_reel_deadline_slips` is folded into the composite-health word of step 2.

```
displayed FPS gauge: 30.0 at VBlank 400 and 4000
SMOKE: PASS off=0x2F len=2 got=0x0777 (ran 4000 frames, bsnes-jg)
```

**PASS** — 1,911 exact presentations, zero deadline slips. Recorded drift: the plan's "716 exact
presentations in 2,400 VBlanks" no longer applies; the window is now 4,000 VBlanks and the
expected count was corrected by `b1afb9c` "fix(snes): reel cadence expectation was 1 too low, and
never right".

### 6. the ROM header and checksum are valid and the ROM boots from a clean emulator state;

Command: `python3 tools/snes-checksum.py --hirom --fast --inspect build/svx2-video-reel.sfc`
(header/checksum), with the clean-boot half covered by every `jgxcheck` run above starting from
power-on.

```
$ python3 tools/snes-checksum.py --hirom --fast --inspect build/svx2-video-reel.sfc
build/svx2-video-reel.sfc
mapping           : hirom (fast ROM), map mode $31
file length       : 4194304 bytes (0x400000, 32 Mbit / 4 MiB)
physical devices  : 32Mbit @ $000000
logical (mirrored): 0x400000 (4 MiB) -> ROM-size byte $0C
header at file    : $00FFB0
canonical windows :
    $C0-$FF:0000-FFFF  <- file $000000-$3FFFFF
addressing holes  : none
title             : 'LLVM-MOS SNES        '
map mode byte     : $31
cartridge type    : $00
ROM-size byte     : $0C
RAM-size byte     : $00  (no save RAM)
region byte       : $01  (bsnes-jg videoRegion: NTSC)
reset vector      : $00:8000 -> file $008000 (first opcode $78)
native vectors    : COP=$0000 BRK=$835D ABT=$0000 NMI=$8037 IRQ=$835D
emu vectors       : COP=$0000 ABT=$0000 NMI=$8037 RES=$8000 IRQ=$835D
checksum stored   : $9BB2   complement $644D
checksum recomputed: $9BB2 (mirrored image) / $9BB2 (multiplier formula)
bsnes-jg heuristic: detects hirom  lorom=0  hirom=14  exlorom=0  exhirom=0

PASS: header, size, decomposition, vectors and checksum all agree.
```

**PASS.**

### 7. the exact verified ROM is the file published in the gallery.

Command: hash the ROM this gate just built, and hash the file currently served by the gallery.

```
$ ls -l build/svx2-video-reel.sfc; sha256sum build/svx2-video-reel.sfc
-rw-rw-r-- 1 will will 4194304 Aug  3 17:18 build/svx2-video-reel.sfc
f741e49a384c20d2cedbe1d7413b5303a0ede7cf28d01293f7a91037eb3ab7d2  build/svx2-video-reel.sfc
```

```
$ curl -fsSL https://biohack.net/play/roms/svx2-fastrom-video.sfc -o /tmp/svx2-published.sfc
$ echo "size=$(stat -c %s /tmp/svx2-published.sfc)"; sha256sum /tmp/svx2-published.sfc
size=8388608
c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2  /tmp/svx2-published.sfc
```

```
$ grep -rn '825e3848917c669481c6da1eac6212d857aa1c399d6a1c2ffba8d264d0708c99' . | grep -v '^./.git'
./docs/plans/2026-07-31-svx2-animated-video-cartridge.md:146:- ROM SHA-256 `825e3848917c669481c6da1eac6212d857aa1c399d6a1c2ffba8d264d0708c99`;
```

**FAIL.** Three distinct images, none matching: this plan's recorded 32 KiB LoROM ROM
`825e3848…` (release `v1.0.317`) survives nowhere but this document; the gate above builds a
4 MiB Fast HiROM `f741e49a…`; and the gallery now serves an 8 MiB ExHiROM `c3d7cd9e…` at
`v1.0.360`, which belongs to the 59.94 fps successor and is gated separately by
`dev/svx2-emulator-validation.sh`. Suspected commits: `21179d7` "feat(snes): prove SVX2 60 fps
pipeline" and the ExHiROM seam work that followed it. Not adjusted — the gate as written cannot
pass against this plan's artifact, and deciding which ROM this plan should now own is a design
call, not a verification one.

**Verdict: 6/7 PASS, 1 FAIL (gate 7), plus a failed preliminary (the LoROM configuration no
longer compiles).**

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

Full two-video continuation completed 2026-07-31:

- 600 NASA SVS animation frames plus all 300 approved real-camera frames in a 2,311,832-byte
  packed SVX2 stream, with one shared shipping palette and independent keyframes;
- 4 MiB Fast HiROM with 16-bit frame indexing and DMA split at 64 KiB ROM-bank boundaries;
- complete host round trip plus target CRCs for every bank-crossing packet and the reset keyframe;
- 716 exact presentations in 2,400 VBlanks, over two complete loops, with zero decoder errors and
  zero deadline slips; and
- frame-115 emulator/host visual gate passes with the corrected Mode 7 dashboard split model.

The integration also exposed a second staged-keyframe defect: the parser selected DBR `$7F` for
high-WRAM token reads, but ordinary indirect run stores and absolute parser-state loads then used
that same bank. The corrected kernel keeps DBR at `$00` and uses explicit long `$7F` reads for
staged token/payload bytes. The existing staged-delta 607/648-per-600 regression and all 17 host
codec tests still pass.
