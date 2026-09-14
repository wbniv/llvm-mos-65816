# SVX2 Animated Video Cartridge

**Date:** 2026-07-31
**Status:** Full two-video 900-frame HiROM cartridge complete; 60 fps optimization and ExHiROM follow-up remain.
**2026‑09‑14:** anchors re-pointed per [`2026-09-14-svx2-anchors-decision.md`](2026-09-14-svx2-anchors-decision.md) —
this plan owns the 4‑frame LoROM integration fixture (restored; `dev/snes-video-lorom-fixture.sh`); gate 7 is
retired here in favour of the successor's `dev/svx2-emulator-validation.sh`.
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
7. ~~the exact verified ROM is the file published in the gallery.~~ **Retired 2026‑09‑14** — the gallery
   serves exactly one SVX2 ROM (`svx2-fastrom-video.sfc`), and that slot moved with the successor plans by
   design (LoROM `v1.0.317` → HiROM → ExHiROM `v1.0.360`). The "published == gated" property is owned by
   [`2026-08-02-svx2-artemis-2x-apollo-60p-reel.md`](2026-08-02-svx2-artemis-2x-apollo-60p-reel.md) via
   `dev/svx2-emulator-validation.sh`; this plan's artifact is the LoROM integration fixture, which is
   complete when gates 1–6 pass. Rationale: [`2026-09-14-svx2-anchors-decision.md`](2026-09-14-svx2-anchors-decision.md), anchor (b).

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
`bd344a1` → `21179d7` → `d6030cf`). *(Correction 2026‑09‑14: the culprit is `d6030cf` — it hoisted the
bank arithmetic into an unguarded `reel_stream_bank()` helper; `bd344a1` and `21179d7` kept every use
inside `#ifdef VIDEO_REEL_PACKED_FAR`. Restored below.)* **FAIL.** Gates 1–6 below are therefore run against the
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

## Verification record — 2026‑09‑14, `wt/svx2-anchors` off `main` @ `294bc8c`

Re-run after the restore-or-retire decision
([`2026-09-14-svx2-anchors-decision.md`](2026-09-14-svx2-anchors-decision.md)). Gates 1–6 are now read
against the plan's own artifact — the 4‑frame LoROM integration fixture — regenerated from tracked assets
by `dev/snes-video-lorom-fixture.sh` (which recovers reel frames 600–603 from the checked-in header +
stream and runs the standard gate). Toolchain as-built (`build/llvm-mos-install/bin/mos-clang`,
`build/jgxcheck`, hardlinked into the worktree); no rebuild.

**Preliminary — the LoROM first cartridge compiles again.** Before (unmodified `294bc8c`, same
recovered tiles):

```
$ VIDEO_REEL_TILES=build/lorom-fixture.tiles VIDEO_REEL_PALETTE=build/lorom-fixture.pal \
  VIDEO_REEL_FRAMES=4 VIDEO_REEL_FIRST_FRAMES=0 dev/snes-video-reel.sh
frames=4 packets=2877 seek=0 loop=828 padding=0 total=3705 max=897
/home/will/llvm-mos-65816-svx2-anchors/examples/snes/snes-video-reel.c:287:20: error: use of undeclared identifier 'VIDEO_REEL_HIROM_BASE_BANK'
  287 |   return (uint8_t)(VIDEO_REEL_HIROM_BASE_BANK + (uint8_t)(offset >> 16));
      |                    ^~~~~~~~~~~~~~~~~~~~~~~~~~
1 error generated.
exit=1
```

The generator line is byte-identical to the 2026‑08‑03 record's, so the recovered frames are the
fixture's original content. After (`reel_stream_bank()` wrapped in `#ifdef VIDEO_REEL_PACKED_FAR`), the
same command builds a 32 KiB LoROM — full log under the gates below. **PASS.**

**Cadence-gate defect found and fixed on the way.** The restored fixture first failed
`dev/snes-video-reel.sh`'s cadence gate at every cadence (`got=0x031D want=0x0319`, `0x018F/0x018D`,
`0x010A/0x0109`) with zero deadline slips and zero CRC failures. Measured `t0` (first present) = 404 at
all three cadences, and `1 + floor((1200 − 404)/CADENCE)` reproduces every observed count exactly; the
stored literals from `4e93daa` encode `t0 = 408`. Same class as `b1afb9c`: stale hardcoded t0, not a
dropped frame. The gate now measures t0 in-run (asserted within ±16 of a documented reference) and
derives the expectation; the FPS-gauge early probe is likewise `t0 + 60 + 8` instead of a fixed 400
(which read `00.0` on this fixture because its first present is at 404). Cause of the 408→404 shift:
the boot path's source is textually unchanged since `4e93daa`; the compiler is not (12 patch commits in
between), so codegen speed is the plausible variable — unverifiable without the 2026‑07‑31 toolchain.

### 1. every generated packet round-trips on the host;

```
$ dev/snes-video-lorom-fixture.sh
==> recover fixture frames 600..603 from the checked-in reel
extracted frames 600..603 (decoded from keyframe 0) -> /home/will/llvm-mos-65816-svx2-anchors/build/lorom-fixture.tiles (17920 bytes); palette -> /home/will/llvm-mos-65816-svx2-anchors/build/lorom-fixture.pal
==> build + gate the 4-frame LoROM fixture
frames=4 packets=2877 seek=0 loop=828 padding=0 total=3705 max=897
```

```
$ python3 -m pytest tests/test_snes_video_codec.py -q
.........................                                                [100%]
25 passed in 12.41s
```

**PASS** — the extractor CRC-checked all 604 sequential decodes against `reel_frame_crcs[]`, the
generator round-tripped every packet it emitted, and the host suite (now including the extractor's
round-trip test) is green.

### 2. every embedded frame passes target-side decoded CRC validation;

```
SMOKE: PASS off=0x207 len=4 got=0x00000000 (ran 1200 frames, bsnes-jg)
```

**PASS** — composite health zero: the boot-validation pass (all four frames CRC-checked on target,
then frame 0 re-decoded and re-checked after the loop) and 1,200 VBlanks with no CRC failure, slip or
result code.

### 3. the first visible frame matches the host raster and palette;

```
jgxcheck: wrote /home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.png (256x224 from native 512x240, yoff=0)
DASHBOARD: PASS ink_pixels=420
FIDELITY: PASS frame=0 exact=93.0542% mae=1.3092
```

**PASS** — compared against the recovered tiles and the shipping palette; 93.05 % exact / MAE 1.31
against the plan's historical 90.32 % / 2.09.

### 4. at least two full playback loops preserve order and keyframe reset behavior;

```
jgxcheck: JGX_POLL matched at frame 411 of 1200 budgeted
SMOKE: PASS off=0x207 len=4 got=0x00000000 (ran 1200 frames, bsnes-jg)
```

**PASS** — 399 presentations of a 4‑frame reel is ~100 loops; the loop gate and the dashboard
loop-time reset latch (matched at VBlank 411, the first wrap) are folded into the composite-health
word.

### 5. the measured presentation count matches the selected VBlank cadence with zero slips;

```
cadence gate: first present at VBlank 404 (reference 404); expecting 0x18f presentations in 1200
displayed FPS gauge: 30.0 at VBlank 472 and 1200
SMOKE: PASS off=0x2F len=2 got=0x018F (ran 1200 frames, bsnes-jg)
```

**PASS** — 399 exact presentations at cadence 2, zero slips (composite health), gauge reads 30.0 in
its first window and at the end. Cadence 1 and 3 were also measured on this fixture: `0x031D` and
`0x010A`, both equal to the t0 = 404 derivation.

### 6. the ROM header and checksum are valid and the ROM boots from a clean emulator state;

```
$ python3 tools/snes-checksum.py --fastrom --inspect build/svx2-video-reel.sfc
mapping           : lorom (fast ROM), map mode $30
file length       : 32768 bytes (0x8000, 0 Mbit / 32 KiB)
physical devices  : 256Kbit @ $000000
logical (mirrored): 0x8000 (32 KiB) -> ROM-size byte $05
header at file    : $007FB0
canonical windows :
    $00-$00:8000-FFFF  <- file $000000-$007FFF
addressing holes  : none
title             : 'LLVM-MOS SNES        '
map mode byte     : $30
cartridge type    : $00
ROM-size byte     : $05
RAM-size byte     : $00  (no save RAM)
region byte       : $01  (bsnes-jg videoRegion: NTSC)
reset vector      : $00:8000 -> file $000000 (first opcode $78)
native vectors    : COP=$8360 BRK=$835F ABT=$0000 NMI=$8037 IRQ=$835D
emu vectors       : COP=$8360 ABT=$0000 NMI=$8037 RES=$8000 IRQ=$835D
checksum stored   : $A5C9   complement $5A36
checksum recomputed: $A5C9 (mirrored image) / $A5C9 (multiplier formula)
bsnes-jg heuristic: detects lorom  lorom=14  hirom=0  exlorom=0  exhirom=0

PASS: header, size, decomposition, vectors and checksum all agree.
```

**PASS** — every `jgxcheck` run above starts from power-on.

### 7. ~~the exact verified ROM is the file published in the gallery.~~

**RETIRED** for this plan (see the gate list and the decision doc, anchor (b)). The successor's
`dev/svx2-emulator-validation.sh` is the owner of "published == gated"; its result on this date is
recorded in the decision doc's verification, step 5 — all emulator gates PASS, but the rebuilt image's
code window differs from the published `v1.0.360` (toolchain drift since the release; the packed video
stream is byte-identical). That finding belongs to the successor plan.

**Verdict: gates 1–6 PASS on the restored LoROM fixture; gate 7 retired; preliminary PASS.**

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

Completed 2026-07-31 — **historical figures** (marked 2026‑09‑14): the ROM hash, release tag and gallery
commit below describe the LoROM fixture as it was published on 2026‑07‑31 and later superseded in the
gallery slot; the fixture itself is regenerated from tracked assets by `dev/snes-video-lorom-fixture.sh`,
and its live figures are in the 2026‑09‑14 verification record.

- four consecutive Artemis press-site camera frames, one keyframe plus three SVX2 deltas;
- 3,433 compressed packet bytes, maximum packet 950 bytes, in a 32 KiB FastROM LoROM;
- host round-trip generation, target CRC validation, keyframe loop reset, and two-loop gate;
- NMI-counted 30 fps scheduler: 482 presentations in 1,200 VBlanks after boot validation, zero
  CRC failures, and zero deadline slips;
- attempted 60 fps scheduler: 160 missed deadlines in 1,200 VBlanks, correctly rejected;
- emulator/host screenshot gate: 90.3163% exact pixels and 2.0916 mean absolute channel error
  after the Mode 7 scaling path;
- ROM SHA-256 `825e3848917c669481c6da1eac6212d857aa1c399d6a1c2ffba8d264d0708c99` *(historical — this image
  survives only in the `v1.0.317` release; it is not reproducible byte-for-byte from today's toolchain)*;
  and
- gallery commit `bd102e8`, release tag `v1.0.317`, with its 1,200-frame live self-check passing
  *(historical — the gallery slot now carries the ExHiROM successor, see gate 7)*.

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
