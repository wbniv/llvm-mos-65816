# SVX2 60 fps — functional ring refill and keyframe scheduling

**Date:** 2026-08-01
**Branch/worktree:** `feature/60fps-video` @ `/home/will/llvm-mos-65816-60fps`
**TODO item:** `TODO.md:132` — `- [T4] **60 fps video playback target**`
**Extends:** [`2026-07-30-exhirom-video-boundary-test.md`](2026-07-30-exhirom-video-boundary-test.md)
(§Frame presentation, §Codec selection), [`2026-07-31-svx2-animated-video-cartridge.md`](2026-07-31-svx2-animated-video-cartridge.md)

## Starting state, corrected by measurement

The dispatch brief described the decoder as still re-reading the ROM packet rather than the staged
high-WRAM copy. **That is stale.** At `main` HEAD `f25d58e`, `snes-video-codec-bench.c` already calls
`svx_decode_payload_wram_fast(0x2009u, …)` under `VIDEO_BENCH_PIPELINE`, i.e. it decodes the bytes
actually staged at `$7F:2009`. Reproduced in this worktree before touching anything:

| Build (600 VBlanks, `VIDEO_BENCH_PIPELINE=1 VIDEO_BENCH_ASM=1`) | median | worst |
|---|---:|---:|
| slow ROM | 540 | 581 |
| FastROM (`$30` + `MEMSEL=$01` + bank `$80`) | **607** | **648** |

FastROM matches the boundary plan's recorded 607/648 exactly. So scope (a)'s *staged-WRAM* half is
done and green. What is **not** done is the half the boundary plan itself defers — "Multi-packet ring
ownership/refill scheduling remains player work". That is this plan.

The margin being defended is thin: 607 decodes per 600 VBlanks is **1.2 % of headroom**. Any
per-frame bookkeeping added by a real stream walk must fit inside that 1.2 %.

## What a real refill adds over the current bench

The bench re-stages **one** packet from **one fixed** ROM address into **one fixed** WRAM address,
every iteration. A player walks a stream. The per-frame costs that are currently unmeasured:

1. 32-bit packet offset/size lookup from a frame table;
2. the A-bus bank-split loop (a packet straddling a 64 KiB ROM bank needs 2 GP-DMA commands);
3. ring write-position bookkeeping and the wrap decision;
4. keyframe/delta dispatch on a per-frame flag.

## Design

**Chosen: per-frame refill into a no-split wrapping ring in high WRAM bank `$7F`.**

- Ring spans `$7F:2000 – $7F:FFFF` (57,344 B), comfortably ≥ 8 × the 3,812 B worst packet.
- **No-split allocation.** `svx_decode_payload_wram_asm` walks its staged cursor with a 16-bit `X`
  and `LDA $7F0000,X`; it has no wrap handling. So a packet is never split across the ring end: if
  `write + bytes > RING_END`, the write position resets to `RING_BASE` *before* the transfer. Cost is
  one compare and a predicted-not-taken branch per frame.
- Refill granularity is **exactly one packet per frame**, matching presentation granularity.
- Source walk reuses the reel's proven packed-far model: stream packed at file `$010000` (HiROM bank
  `$C1`) by `tools/snes-video-pack-hirom.py`, 32-bit per-frame offsets, A-bus bank split at each
  64 KiB boundary.

**Rejected: a prefetch ring that overlaps refill with decode.** On this hardware GP-DMA *halts the
CPU* for the whole transfer, so there is no DMA/CPU concurrency to recover. A prefetch ring would add
ownership bookkeeping to buy exactly zero throughput. The ring's justification here is wrap-safety
and stream ownership, not overlap — and that must be stated, because "ring" normally implies overlap.

**Rejected: batched refill, one GP-DMA per *k* packets.** It does recover the per-transfer setup cost
(~1 DMA setup out of every *k* frames). But it converts a flat per-frame cost into a burst *k* times
larger than one frame's staging DMA, landing entirely inside one frame period. With 1.2 % of margin
there is nothing to absorb a burst with, and a hard 16.7 ms deadline prefers flat-and-predictable
over lower-mean-with-jitter. Revisit only if the flat design misses.

## Keyframe scheduling (scope b)

Keyframe *packets* are small — measured over the 300-frame Floyd corpus at a 60-frame interval:
950 / 1,532 / 2,735 / 3,453 / 3,436 B, all at or below the 3,127 B median **delta**. Packet size is
therefore not the keyframe risk. The risk is the decode *path*: `svx_key_*` copies literals with a
per-byte `LDA long / STA abs,Y / INX / INY / DEC / BNE` loop, where the delta path moves whole spans
with `MVN`. Neither existing bench case is a keyframe (median = frame 236, worst = frame 157, both
deltas), so keyframe cost has never been measured.

This plan adds bench **case 7 = `svx-keyframe`** so the cost lands in the same
decodes-per-600-VBlanks units as every other case, and the schedule is chosen on the number rather
than on the assumption.

## Verification

1. Baseline reproduction, slow + FastROM, 600 VBlanks (recorded above).
2. Keyframe case cost, slow + FastROM, 600 VBlanks.
3. Stream/ring mode, slow + FastROM, 600 VBlanks, with a boot CRC pass covering every frame in the
   loop. Byte-correctness is a stop condition, not a warning.
4. Thresholds in the boundary plan's §Codec selection updated in the same commit as the numbers.

## Measured results

### Slice choice matters — measure, don't assume

The obvious stream slice (frames 0–119) is **not** representative: its mean packet is 1,523 B against
3,290 B for the hardest 120-frame window (start = 160). Reporting only the easy slice would have
overstated the margin by ~6 %. Both are reported; the hardest slice is the gate.

| Build (`VIDEO_BENCH_STREAM=1`, 600 VBlanks, warmup-excluded) | slow ROM | FastROM |
|---|---:|---:|
| stream slice start = 0 (mean 1,523 B/packet) | 574 | 648 |
| **stream slice start = 160 (hardest, mean 3,290 B/packet)** | **544** | **610** |
| single-packet reference (`VIDEO_BENCH_PIPELINE`, median / worst) | 540 / 581 | 607 / 648 |

**Scope (a) verdict: the functional multi-packet ring refill holds 60 fps on FastROM — 610/600 on
the hardest slice, against 607/600 for the single-packet proxy.** The stream walk (32-bit offset
lookup, A-bus bank split, ring wrap) costs within measurement noise of the fixed-address proxy, so
the 1.2 % margin survives. Slow ROM remains short at 544/600 (54.4 fps), consistent with the
boundary plan's 542.

Measurement is now two-point — iterations are read at the warmup mark and again 600 VBlanks later,
and the difference is reported — so the whole-loop validation pass no longer dilutes the number.

### The gate is not vacuous

Flipping one byte inside the packed stream (file `$01C350`) makes the run stop with
`corpus_result = 2`:

```
--- control: unmodified ROM ---
SMOKE: PASS off=0x22 len=1 got=0x00 (ran 1200 frames, bsnes-jg)
flipping file offset 0x01c350: 0xd3 -> 0x2c
--- negative control: one corrupted stream byte ---
SMOKE: FAIL off=0x22 len=1 got=0x02 want=0x00
```

The ring wrap is likewise proven taken, not assumed: `video_bench_ring_wraps` reads `0x001C`
(28 wraps) after 1,200 VBlanks on the hardest slice.

### Keyframes are the remaining cliff (scope b)

| case (600 VBlanks) | slow ROM | FastROM | VBlanks per frame (FastROM) |
|---|---:|---:|---:|
| `svx-median` delta | 540 | 607 | 0.99 |
| **`svx-keyframe`** (new case 7, frame 180, 3,453 B) | **176** | **207** | **2.90** |

A keyframe costs ~2.9 VBlanks — nearly 3× its budget. Presentation is VBlank-locked, so the slack a
delta frame leaves (~0.05 VBlank) **is not bankable**: a keyframe misses its deadline every time and
slips ~2 VBlanks under the slip-never-tear policy. At a 60-frame interval that is 2 slips per 60
frames — 58.1 fps effective and a visible hitch once a second. **A strict 600/600 gate and periodic
keyframes are therefore incompatible with the keyframe kernel as written.**

Cause, located: the delta path moves whole spans with `MVN` (7 cycles/byte), but the keyframe
PackBits *literal* path in `svx_decode_payload_asm` copies one byte at a time —
`LDA long / STA abs,Y / INX / INY / DEC dp / BNE` ≈ 24 cycles/byte. A PackBits literal run is
exactly a block copy, so it should use the same `MVN` the delta path already proves.

### Keyframe fix, and where the rest of the cycles actually go

Replacing the literal byte loop with `MVN` (`snes-video-codec-fast.s:157`) improves the keyframe case
**207 → 300** decodes/600 FastROM (2.90 → **2.00** VBlanks), byte-correct, with **no delta
regression** — `svx-median` and `svx-worst` stay at exactly 607 and 648.

It does not close the gap, and the reason is measured rather than guessed. Token histogram of the
frame-180 keyframe packet:

| | tokens | bytes emitted | mean run length |
|---|---:|---:|---:|
| literal | 143 | 3,007 | 21.0 |
| run | 147 | 1,473 | 10.0 |

290 tokens for 4,480 output bytes. Floyd–Steinberg dithering fragments PackBits, so the kernel is
**token-dispatch-bound, not copy-bound** — which is exactly why optimizing the copy bought 45 % and
no more. The identified next lever is a *staged keyframe specialization*, mirroring what
`svx_decode_payload_wram_asm` already does for deltas: with the source bank fixed at `$7F` the
per-token `lda __rc12 / beq` test and its `sep`/`rep` mode flips disappear from all three read sites.
Not attempted here — see "Not finished" below.

### Schedule recommendation (scope b)

With keyframes at 2.00 VBlanks, presentation VBlank-locked, and delta slack unbankable, the honest
options are:

1. **Deterministic 2-VBlank keyframe slot.** Schedule the keyframe as a planned two-VBlank frame
   rather than letting it slip. Visually identical to a slip, but deterministic, so the cadence gate
   can encode it exactly (`expected = 600 − keyframes`) instead of tolerating slop. Preserves
   slip-never-tear. Costs 1 VBlank per keyframe interval — 59.0 fps effective at interval 60.
2. **No periodic keyframes for linear playback** — keyframes only at frame 0 and hard cuts, which is
   what the shipped reel already does (`snes-video-reel.c:44`). Costs nothing and holds a true
   600/600. Price: no mid-stream seek targets.

These differ only in whether mid-stream seek is required, which the transport/scrubbing plan owns,
not this one. Recommended: (2) for the linear reel now, (1) as the shape to adopt the moment
scrubbing lands — with the staged-keyframe specialization as the way to make (1) free.

### Scope (c) — true-60 content, analysis only

- **No content acquired, and none should be**: there is no documented video-fetch path in `tools/`
  or `dev/`. The `dev/fetch-*.sh` scripts fetch compiler torture suites and the 65816 oracle, not
  video masters. Acquiring masters would mean inventing a fetch path, which this task excludes.
- The requirement stands as the boundary plan states it: true 60 fps motion needs **≥ 59.94 fps
  masters**; the nominated source is NASA SVS item 14191 (`Pre-launch_through_launch.webm`,
  `Return_to_Earth.webm`), whose frame rates are unverified here because verifying them requires
  downloading them. **This is the missing evidence** — one `ffprobe` of each master settles it.
- A 29.97/30 fps master frame-doubled to the 60 fps cadence is not a compromise on *throughput*: it
  halves decode load. It is a compromise on *motion*, which stays 30 fps. Never interpolate.

### Scope (d) — ExHiROM capacity at 60 fps, rechecked

Measured SVX2 ratios: real-camera corpus 2,553 B/frame mean (300 frames, 765,969 B); the shipped
900-frame reel agrees closely at 2,569 B/frame. A **duplicated** frame encodes to exactly **44 bytes**
(all-copy delta) — measured, constant across the corpus.

Video budget = capacity − 256 KiB reserved for runtime, boundary fixtures and header.

| Capacity | 30 fps native | 60 fps **true** | 60 fps frame-doubled 30 fps master |
|---|---:|---:|---:|
| 6 MiB (48 Mbit: ROM 1 4 MiB + ROM 2 2 MiB) | 78.7 s | **39.4 s** | 77.4 s |
| 8 MiB | 106.1 s | **53.0 s** | 104.3 s |

**Verdict.** The "stream size ×2/second" concern is real but applies only to *true* 60 fps content:
6 MiB holds ~39 s of it, against the plan's 8–10 s per excerpt × 2 excerpts, so **the nominated
Artemis reel fits in 6 MiB at true 60 fps with ~2× headroom**. Frame-doubling a 30 fps master costs
1.7 % over 30 fps native (44 B per duplicate), i.e. capacity is a non-issue on that path. Capacity is
therefore *not* the binding constraint at 60 fps — decode throughput and keyframe scheduling are.

## Not finished

- The staged-keyframe specialization (bank fixed at `$7F`, no per-token bank test) is identified and
  motivated by the token histogram but **not implemented**. Expected to be what makes option (1)
  above free; unproven.
- Reel-side integration is untouched by design — see below.

## Merge-ready state

Branch `feature/60fps-video`, not pushed, not merged. Clean against `main` for everything this plan
touches **except** that the reel corridor was deliberately avoided: `examples/snes/snes-video-reel.c`,
`examples/snes/video_hud.h` and `dev/snes-video-reel.sh` carry another worker's uncommitted edits on
`main`. `snes-video-codec-fast.s` **is** shared with the reel — the keyframe `MVN` change affects it,
and it is verified byte-correct with no delta regression, but that reconciliation is the other
worker's call, not this branch's.

## Out of scope, stated plainly

- Scope (c) is **analysis only** — no content acquisition; no fetch path is being added.
- Reel-side integration is deliberately not attempted: `examples/snes/snes-video-reel.c`,
  `video_hud.h` and `dev/snes-video-reel.sh` carry another worker's uncommitted edits on `main`.
