# Un-work-around `maze.h`'s two-pass split — fold while walking `came[]`

**Date:** 2026‑09‑14 · **Status:** COMPLETE · **Tier:** T3 · **Worktree:** `wt/maze-refold`

## Problem

`examples/65816/maze.h`'s `maze_fold_path()` folds the A* shortest path in **two passes**: it calls
`maze_path_build()` to materialize the whole `goal→start` cell chain into `m->heap[]`, then walks that
flat array folding `(c << 2) | came[c]`. Its comment says the split is deliberate — *"never
fold-while-walking (the combined load-at-top / step-at-bottom loop makes GISel hoist a merge past its
use)"*.

That is a **compiler work-around, not a design choice.** The abort it dodges was
`-verify-machineinstrs`'s *"Virtual register defs don't dominate all uses"*, root-caused and **fixed on
2026‑06‑29** (`fb528d8`): `MOSLegalizerInfo::tryAbsoluteIndexedAddressing`'s seed‑56 workaround built the
`trunc`/zero-extend at the `G_PtrAdd`'s *body* block and replaced every use of the offset — including a
sibling loop-header use. The fix inserts it at the offset's SSA **definition**. The exact shape is now a
standing gate: `examples/65816/legalindexdom.c` / `dev/legalindexdom.sh`.

The project's standing directive is **"stress the compiler, never work around it"**, so the work-around
should come out now that the defect is fixed.

## Design

1. `maze_fold_path()` folds **while walking** `came[]` directly — load the cell at the top, fold it, test
   for `start`, step at the bottom — with the *same* bound (`step <= MAZE_N`) and the *same* termination
   (`cell == start`) as `maze_path_build()`. No `heap[]` pass.
2. `maze_path_build()` **stays**, unchanged: `examples/snes/maze.c` (the on-console demo) calls it to
   light the solved path, and its `noinline` small-frame comment is still the reason it exists separately.
3. **The CRC must not move.** `maze_path_build()` writes `heap[n++] = cell` at the *top* of its loop and
   the old fold walked `heap[0..n-1]` in index order — i.e. exactly `goal → … → start`. The re-folded loop
   folds the same `cell` values in the same order, so `maze_gate_crc()` must still be `0x0749`. If the
   walk order turned out to differ, that is a stop-and-explain, not a re-baseline.
4. Comments: the "never fold-while-walking" note becomes a note that this loop is **deliberately** the
   shape that used to break the legalizer, gated by `legalindexdom`.

**Visible surface:** none. The demo's rendering is unchanged (`maze_path_build()` is untouched and is what
the demo draws from); only the gate CRC's internal computation shape changes. No mockups.

**If `-verify` fails on the re-folded shape** that is a **compiler finding**, not something to work around:
capture the error + MIR, leave the split in place, and escalate.

## Files

- `examples/65816/maze.h` — `maze_fold_path()` re-folded; comments updated.
- `TODO.md` — item → `[wip T3]` → Done.
- this plan.

## Verification

1. `-verify-machineinstrs` clean for `examples/snes/corpus/maze_sim.c` at `-Os` in all three modes
   (default 8-bit, `+mos-a16`, `+mos-xy16`).
2. `dev/run.sh legalindexdom` PASS.
3. `dev/run.sh maze` PASS, host oracle hash still `0x0749` on bsnes-jg (MAME if present).
4. The corpus gate that includes `maze_sim.c`: `dev/run.sh corpus` and `dev/run.sh corpus-a16`.
5. Byte-size note: `maze.sfc` and the `maze_sim` object `.text` sizes before vs after.

### Results (2026‑09‑14)

**1. `-verify-machineinstrs` clean for `maze_sim.c` at `-Os`, all three modes.**

```text
$ T=build/llvm-mos-install/bin
$ "$T/mos-clang" --target=mos -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs \
    -c examples/snes/corpus/maze_sim.c -o /tmp/after_default.o
--- after_default ---
exit 0
--- after_a16 ---      (-Xclang -target-feature -Xclang +mos-a16)
exit 0
--- after_xy16 ---     (-Xclang -target-feature -Xclang +mos-xy16)
exit 0
```

**PASS** — no diagnostic, exit 0 in all three modes. The fold-while-walk shape that used to abort with
*"Virtual register defs don't dominate all uses"* now compiles clean; `fb528d8` holds.

**2. `dev/run.sh legalindexdom`**

```text
    PASS  default  (-verify clean)
    PASS  +mos-a16  (-verify clean)
    PASS  +mos-xy16  (-verify clean)

RESULT: PASS — indexed-addr domination fix live; repro -verify clean in default/+mos-a16/+mos-xy16
```

**PASS**

**3. `dev/run.sh maze`**

```text
==> host oracle: maze generate+solve gate hash = 0x0749
==> built build/maze.sfc (+mos-a16); corpus_result @ WRAM 0xe44
==> disasm gate (recursion self-call + native-16 codegen)
    PASS  recursion(maze_divide self-call)=3  rep/sep=220  (genuine recursion + native-16)
==> bsnes-jg: render + framebuffer dump (build/maze-jg.png) + assert
SMOKE: PASS off=0xE44 len=2 got=0x0749 (ran 400 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/maze-mame.png)
    SHOT: PASS corpus=0x0749 (snapshot at frame 400)

RESULT: PASS — maze gen+solve rendered on SNES; bsnes-jg (+ MAME if present) + corpus hash 0x0749 host == +mos-a16
```

**PASS — CRC unchanged at `0x0749`** on the host oracle, bsnes-jg **and** MAME (the SPC700 IPL is
present in this worktree, so the MAME leg ran). No re-baseline needed: the walk order is identical to
the old `heap[]` order, as predicted.

**4. corpus gates**

```text
$ dev/run.sh corpus
  …
  nmitally_sim PASS  corpus_result=0xBCE6  …
==> corpus: 63/63 passed
```

**PASS — 63/63** (includes `maze_sim`).

```text
$ dev/run.sh corpus-a16
  cardioid_sim PASS   corpus_result=0x523B  …
  …
==> corpus-a16: 62/62 passed, 0 xfail
```

**PASS — 62/62, 0 xfail** (`host == default == +mos-a16 == +mos-xy16`). Note: my log filter was
`… | tail -30`, so the per-slice `maze_sim` line fell outside the captured window; the aggregate
`62/62 passed, 0 xfail` covers it (any `maze_sim` disagreement would have failed the run).

**5. Byte sizes (before → after)**

`maze_sim.c` object, `-Os`, sum of `.text*` (the corpus slice — `maze_path_build` becomes unreferenced
there and is dropped entirely, so the whole first pass disappears):

| build | before | after | Δ |
|---|---:|---:|---:|
| default 8‑bit | 4212 B | 4056 B | **−156 B** |
| `+mos-a16` | 3706 B | 3575 B | **−131 B** |
| `+mos-xy16` | 3296 B | 3197 B | **−99 B** |

Per-function, `+mos-a16`: `maze_fold_path` 160 → 195 B (+35, it absorbed the walk), `maze_path_build`
166 → 0 B (dropped). Everything else byte-identical.

The on-console demo ROM `build/maze.sfc` (`+mos-a16`, full link) goes the *other* way, and that is
expected: `examples/snes/maze.c` still calls `maze_path_build()` to light the path, so nothing is dropped
there — only `maze_fold_path` grows.

| artifact | before | after | Δ |
|---|---:|---:|---:|
| `maze.sfc` `.text` | 13633 B | 13676 B | **+43 B** |
| `maze.sfc` file | 32768 B | 32768 B | 0 (fixed 32 KiB bank) |

Net: removing the `heap[]` pass is a **win wherever `maze_path_build()` is otherwise unused** (the corpus
slice, −131 B under `+mos-a16`) and a small **+43 B** in the demo, which keeps both functions. The point
of the change is the work-around removal, not the bytes.

Host oracle cross-check (`tools/maze-sim.c`, the same header compiled natively) before **and** after:
`maze gate_crc = 0x0749` — the folded sequence is provably unchanged.

## Outcome

The work-around is gone: `maze_fold_path()` is a single fold-while-walk loop again, the shape that used
to abort `-verify-machineinstrs`, and it compiles clean in all three modes with the CRC unchanged. No
compiler defect surfaced — `fb528d8` is confirmed live against the original real-world shape that
motivated it, not just against the reduced `legalindexdom.c` repro.

