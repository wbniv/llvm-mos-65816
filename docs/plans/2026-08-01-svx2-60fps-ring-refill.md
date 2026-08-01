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

## Out of scope, stated plainly

- Scope (c) is **analysis only** — no content acquisition; no fetch path is being added.
- Reel-side integration is deliberately not attempted: `examples/snes/snes-video-reel.c`,
  `video_hud.h` and `dev/snes-video-reel.sh` carry another worker's uncommitted edits on `main`.
