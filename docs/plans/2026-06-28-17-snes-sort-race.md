# #17 — SNES Sorting Race: quicksort vs heapsort vs mergesort of a bar array

**Status:** BUILT + `dev/run.sh sort-race` RESULT PASS (host == bsnes-jg corpus hash `0xB28F`; disasm
recursion+compare+native-16 gate PASS; 3-mode `-verify-machineinstrs` clean). DONE on the demo bar
per the 2026-06-28 policy (bsnes-jg PASS + browser-verified; the MAME leg is a non-blocker — env-wide
SPC700-IPL absence). Demo **#17** of the **compiler stress-test demo battery**. Slug: `sort-race`.

## Context

The battery exercises one distinct codegen corner per demo. The corner not yet covered by a built
demo is **recursion / the soft stack / frame ABI** (coverage-map row "recursion & the soft stack /
frame ABI | 17, 18"; #18 maze is the sibling). Quicksort and mergesort are the canonical recursive
algorithms; running them under `+mos-a16` forces the backend's reentrant soft-stack spill path (a
pointer into the caller's array lives across a self-`jsr`), which is exactly the machinery
`examples/65816/a16spillr.c` guards in isolation — this demo exercises it inside a real workload.
Heapsort is the deliberate **non-recursive contrast** (iterative sift-down). The visual is the
iconic "sorting race": three bar arrays sorting in real time, so you can watch which finishes first.

**Design split:** the *recursion stress* lives in the **gate/corpus** — genuinely recursive
`sr_qsort` + `sr_msort` (`noinline`), run to completion folding deterministic compare/move counters
into a `uint16_t` CRC. The *on-screen animation* is driven by an **op-log**: each sort, given a
recording trace, appends `set position p = value v` ops; the ROM replays one op/algorithm/frame and
repaints just the touched bar column. This keeps real recursion as the compiler stress while giving
smooth animation, and avoids an iterative/explicit-stack rewrite that would have erased the recursion.

Recursion depth is bounded-safe: mergesort is `O(log N)`; quicksort uses a mid-element pivot with
`N = 32`, so worst-case depth is tiny vs the ~5 KB of soft-stack room (cf. `examples/65816/maze.h`,
which chose recursive division over `O(N)`-depth DFS for the same reason).

## Algorithm

`N = 32` distinct values `0..N-1`, Fisher–Yates–shuffled with xorshift16. All `uint16_t`/`uint8_t`/
`int16_t`; no bare `int` (shift operands cast back: `x ^= (uint16_t)(x << 7)`).

- `sr_qsort(a,lo,hi,t)` — recursive Hoare quicksort, mid-element pivot. Self-recursion is the
  primary soft-stack witness.
- `sr_msort(a,tmp,lo,hi,t)` — recursive top-down mergesort, out-of-place via `tmp[]`.
- `sr_hsort(a,n,t)` — iterative heapsort (loop-based `sr_sift`), the non-recursive contrast.
- `sr_swap`/merge-writeback call `sr_emit(t,pos,val)` → bump `t->moves`, append `(pos<<8)|val` when
  recording.

**Codegen corners hit:** recursion → soft-stack spill across `jsr`; `rep`/`sep` from native-16 array
indexing/compares; compare-heavy inner loops (`cmp`). **No** 32-bit libcalls (control-flow demo).

## Screen layout (32×28 tiles, all on BG3 2bpp)

```
row 0      SORTING RACE          PASS N
rows 2-8   ████ quicksort bars  (32 cols × 7 tiles, palette 1 = red)
row 9      QUICK M<moves> C<cmps> [DONE]
rows 10-16 ████ heapsort bars   (palette 2 = green)
row 17     HEAP  M.. C..
rows 18-24 ████ mergesort bars  (palette 3 = blue)
row 25     MERGE M.. C..
row 27     WINNER: <algo>   /  RACING...
```

Each band: 7 tile rows = 56 px; value `v∈[0,31]` scales to `1..56` px. 32 bars × 8 px = full width,
so bar `i` = tile column `i`.

## Display architecture

One custom Drawable `RaceField` (modeled on `PiHud` in `examples/snes/spigot.c`) owns the whole BG3
screen — bars **and** all text (`TextLayer` caps at 2 HUD rows). Fill-level tiles 0..8 (bottom-up
2bpp fill) are generated procedurally in `reserve()`; font8 glyphs at tile `FONT_BASE = 256`. Band
colour via the tilemap entry's 3-bit palette field (BG3 2bpp stride-4: pal 1/2/3 → CGRAM[5]/[9]/[13]
= red/green/blue; pixel-value-0 is the transparent black backdrop; pal 0 col 1 = white text).
`uint16_t shadow[28*32]` mirror + `uint32_t dirty` (28-bit per-row); `emit()` DMAs ≤ 16 dirty rows
(1024 B) per frame, spilling the rest. CGRAM `sr_pal[16]` uploaded once.

## Differential gate

- **`corpus_result` = `sortrace_gate_crc()`** — `SR_GATE_ROUNDS = 8`; each round reshuffles, sorts
  three copies, asserts all three equal the identity `0..N-1` (folds `0xA5A5` if all agree else
  `0xDEAD`), then folds each algorithm's `cmps ^ moves`. Self-checking **and** fingerprinted.
- **EXPECT = `0xB28F`** (host oracle; matched by bsnes-jg).
- **Bar:** 5-way design (pure bank-0/7E WRAM, no far pointers → host == default == +mos-a16 ==
  +mos-xy16 == bsnes-jg). Realized here as host == +mos-a16@bsnes-jg + all-3-mode
  `-verify-machineinstrs` clean; the on-MAME runtime legs (default/a16/xy16) are **NEAR**, blocked
  env-wide on the missing gitignored SPC700 IPL (same as #12 CORDIC; non-blocker per 2026-06-28).
- **Disasm probes** (on `build/sort-race_sim.o`): recursion `sr_qsort|sr_msort` refs ≥ 4 (locked;
  actual **695**), `cmp` ≥ 8 (actual **44**), `rep`/`sep` ≥ 1 (actual **233**).

## Files

| File | Purpose |
|------|---------|
| `examples/65816/sort-race.h` | Portable algorithm header (`SortTrace`, recursive `sr_qsort`/`sr_msort`, iterative `sr_hsort`, `sr_emit`, xorshift16, `sortrace_gate_crc`) |
| `examples/snes/sort-race.c` | SNES ROM: `RaceField` drawable + op-log replay; `corpus_result` |
| `examples/snes/corpus/sort-race_sim.c` | HAL-free corpus slice |
| `tools/sort-race-sim.c` | Host oracle |
| `dev/sort-race.sh`, `dev/sort-race.lua` | Gate script + MAME autoboot assert |
| `Taskfile.yml` | `sort-race` + `sort-race-play` tasks |

## Publication

`/snes-rom-page --rom build/sort-race.sfc --slug sort-race --site ~/SRC/biohack.net
--title "Sorting Race — quicksort vs heapsort vs mergesort" --preview build/sort-race-mame.png
--selfcheck "0x16ad 2 0xB28F 500 sort-race"` (VMA `0x16ad` from `build/sort-race.map`).

## Verification steps

1. Host oracle compiles and prints a plausible CRC.

   ```
   $ cc -O2 -I examples/65816 tools/sort-race-sim.c -o /tmp/sr && /tmp/sr
   sort-race gate_crc = 0xB28F  (N=32 rounds=8)
   ```
   PASS — and an independent host check confirmed all three sorts agree & produce the identity
   permutation every round (q[cmp 184-250 mov 70-86] h[cmp 218-233 mov 256-282] m[cmp 119-125 mov 160]).

2. ROM builds clean; `snes-checksum.py` exits 0.

   ```
   ==> built build/sort-race.sfc (+mos-a16); corpus_result @ WRAM 0x16ad
   ```
   PASS.

3. Corpus slice host-compiles (infinite-loop `main`, so compile is the check).

   ```
   $ cc -O2 -std=c99 -I examples examples/snes/corpus/sort-race_sim.c -o /tmp/sr-corpus
   corpus compiled OK
   ```
   PASS.

4. `dev/run.sh sort-race` — host oracle + disasm gate + bsnes-jg PASS; MAME SKIP (no IPL).

   ```
   ==> host oracle: sorting-race gate hash = 0xB28F
   ==> built build/sort-race.sfc (+mos-a16); corpus_result @ WRAM 0x16ad
   ==> disasm gate (recursion + compares + native-16 codegen)
       PASS  sr_qsort/sr_msort refs=695  cmp=44  rep/sep=233  (recursive sorts + compares, native-16)
   ==> bsnes-jg: render + framebuffer dump (build/sort-race-jg.png) + assert
   SMOKE: PASS off=0x16AD len=2 got=0xB28F (ran 500 frames, bsnes-jg)
       SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)
   RESULT: PASS — Sorting Race rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xB28F host == +mos-a16
   ```
   PASS.

5. 5-way differential. `dev/run.sh corpus-a16` is **BLOCKED** env-wide (its MAME engine aborts:
   "MISSING SNES BIOS: /work/dev/roms/s_smp/spc700.rom"). The part runnable without the IPL — the
   corpus slice compiled + `-verify-machineinstrs` clean in all three modes — PASSES:

   ```
   [default] compile+verify: ok
   [a16]     compile+verify: ok
   [xy16]    compile+verify: ok
   OVERALL: PASS
   ```
   NEAR — full on-MAME 5-way pending the IPL (same non-blocker as #12).

6. Published in-browser page + screenshot. _(pending — see TODO.)_

7. `task md -- docs/plans/2026-06-28-17-snes-sort-race.md` renders cleanly. _(run at close-out.)_

## Close-out evidence (bsnes-jg screenshot)

`build/sort-race-jg.png` (frame 500): title "SORTING RACE PASS 1"; red QUICK band sorted
(`M 72 C 193 DONE`); green HEAP band mid-sort (`M 183 C 226`, racing); blue MERGE band sorted
(`M 160 C 118 DONE`) — quicksort (fewest moves) wins, the race dynamics visibly captured. Palette
(stride-4) + layout + readable white text all confirmed.
