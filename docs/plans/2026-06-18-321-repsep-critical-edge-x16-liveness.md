# Plan: REPSEP Critical-Edge Bail Truncates Cross-Block-Live X16 (seed-31)

**Date:** 2026-06-18
**Issue:** #321, ROADMAP M2
**Prereq:** `2026-06-18-321-xy16-hang-fix-xhigh.md` (XHigh + `requiredXWidth` pseudo fix) — landed;
took fuzz 16/50 → 49/50, cleared all 34 hangs.
**Baseline:** `dev/run.sh fuzz 50 1` → **49/50**, the single residual is seed-31, a *mismatch*
(`xy16@MAME=0x0CCC` vs expected `0x0B1F`), **not** a hang.

> **STATUS (2026-06-18): IMPLEMENTED, VERIFIED-CORRECT, then REVERTED — BLOCKED.**
> The `B.begin()` fix below fixes seed-31 and passes **fuzz 50/50** + the full suite. But a wider
> sweep — `dev/run.sh fuzz 200 1` — exposed a **regression at seed-160** (was PASS on the bail
> path, FAIL with the fix). Root-caused (see *§Why this is blocked* below): the fix is itself
> correct, but by removing the whole-function bail it makes critical-edge functions use the
> cross-block dataflow's loop-mode-*holding*, which surfaces a **pre-existing latent bug** — the
> X-agnostic **transfer instructions** (`TAY`/`TYX`/… whose width is governed by the X flag) are
> not modelled in `requiredXWidth`. Per the prime directive (never regress), the fix was **reverted
> to the bail** (vendor + `0002` back to the [hang-fix](2026-06-18-321-xy16-hang-fix-xhigh.md)
> commit, byte-identical). **seed-31 stays open**, now *blocked on first fixing the
> transfer-instruction X-annotation* (TODO M2; the hang-fix plan's *Deferred* item #2, which now
> has concrete evidence: seed-160).

---

## Root cause (fully diagnosed)

`MOSInsertREPSEP`'s cross-block lattice (Steps 1–3 in `runOnMachineFunction`) **bails the whole
function to `placeLegacy`** when a mode transition would land on a *true critical edge* (source
has >1 successor **and** target has >1 predecessor):

```cpp
} else {
  Bail = true; // critical edge — conservative whole-function fallback
  break;
}
...
if (Bail) { Changed |= placeLegacy(MF); return Changed; }
```

`placeLegacy` is per-block and 8-bit-anchored: it restores **both** M and X to 8-bit at *every*
block's terminator. That is safe for **M** (the backend never holds `A16` live across an edge —
it spills to an `Imag16` ZP slot), but it is **unsafe for X**: the register allocator *does* keep
`$x16` live in the physical X register across edges.

### seed-31 trace (function `main`)

```
bb.0:                                   ; X comes up to 16-bit for the load
  ...
  rep #$10
  $x16 = LDXAbs16 @arr+8                ; X16 = arr[4] = 0x3C7D   ← live-out to bb.1
  rep #$20 ; lda/eor/cmp (A16 work)
  sep #$30                              ; placeLegacy end-of-block restore: M=8 AND X=8
  BR bb.2                               ;   → the #$10 here ZEROES X.high: 0x3C7D → 0x007D
bb.1:                                   ; liveins: $x16   (the truncated value)
  rep #$10
  cpx #128                              ; compares 0x007D(125) < 128  → WRONG branch
                                        ;   (correct: 0x3C7D(15485) ≥ 128)
```

The flipped branch diverts control flow and corrupts `corpus_result`. The triggering critical
edge is `bb.1→bb.3` (bb.1 ends X16 via `CPXImm16`; bb.3 enters X8 via `JSR`), which forces the
bail; the damage is collateral, at the end of `bb.0`.

This bug is **independent of the XHigh change** — both edges' X-modes are identical with or
without it. The XHigh fix merely removed the byte-level corruption that previously *hung* seed-31
(`0x0000`), exposing this latent control-flow bug. The XHigh change is a strict improvement.

---

## Fix

Replace the whole-function `Bail` with **targeted placement of the entry switch at the target
block's start** (`B.begin()`), which coerces *every* in-edge to `B`'s required entry width in one
`rep`/`sep`. This keeps the precise dataflow path (Step 3b intra-block + 3c edge transitions) for
the rest of the function, so `$x16` stays 16-bit across `bb.0→bb.1` (no end-of-`bb.0` restore).

### Why `B.begin()` placement is correct

`insertSwitch` emits an **absolute** mode set (`rep`→16 / `sep`→8) to `B`'s entry width
(`In[B]`/`XIn[B]`), which is a single well-defined value. Forcing it at `B.begin()`:

- is correct for **all** in-edges (each pred is coerced to the needed width; preds that already
  delivered it get a harmless redundant switch);
- never truncates a value live **through** `B`:
  - **M:** `A16` is never live across an edge (always spilled to `Imag16`). Always safe.
  - **X:** truncation could only happen on a forced `sep #$10` while an X16 value is live-through
    `B`. A live-through X16 requires `B` to *not* clobber X — i.e. `B` is X-**passthrough**. But a
    passthrough-X block's `XIn[B]` is the `meet` of its preds; if all preds are X16, `XIn[B]=X16`
    (we emit `rep`, no truncation); the only residual risk is **X-passthrough + preds X-conflict**
    (`meet → XW_Conflict → X8`). For a **non-passthrough** `B` (its first X-op pins `XIn[B]` and
    operates on X at that width, clobbering any prior value) there is no live-through X16.

So the rule: on a critical edge needing a transition, **place at `B.begin()`** — *unless* the X
flag would be forced to X8 **and** `B` is X-passthrough with conflicting preds, in which case keep
the conservative `placeLegacy` bail. seed-31's `bb.3` is non-passthrough (`ldx #9` pins X8), so it
takes the `B.begin()` path.

### Implementation sketch (`MOSInsertREPSEP.cpp`, Step 3a/3c)

Restructure the per-edge loop so that, per non-entry block `B`:

1. Compute `needM/needX` and, over preds, `anyMDiff/anyXDiff` and whether any *critical* in-edge
   needs a transition (`P.succ>1 && B.pred>1 && (md||xd)`).
2. If a critical in-edge needs a transition **and** the safe condition holds (not the
   X-passthrough-conflict case), push a single `B.begin()` placement
   `{B, AtEnd=false, MChanged=anyMDiff, ToM16=needM, XChanged=anyXDiff, ToX16=needX}` and skip
   per-edge placement for `B`.
3. If the unsafe X-passthrough-conflict case is hit, set `Bail` (retain the existing fallback).
4. Otherwise, per-edge placement exactly as today (single-succ pred → pred end; single-pred B →
   `B.begin()`).

Keep the `Bail`/`placeLegacy` machinery as the residual safety net for the rare unsafe case.

---

## Why this is blocked (seed-160 regression — root cause)

The `B.begin()` placement is correct *in isolation* (it delivers each block's `In`/`XIn` exactly,
A16 is never live across edges, and the X-passthrough-conflict corner still bails). The problem is
a **second-order interaction**: removing the whole-function bail makes a *critical-edge* function
use the cross-block dataflow's loop-mode-**holding** (Increment 2: hoist `rep`/`sep` out of loops)
instead of `placeLegacy`'s per-block 8-bit anchoring. That holding exposes a **pre-existing latent
bug** that the bail was inadvertently masking.

**seed-160's loop** (`bb.1`, a `for (y=0; y<16; y+=2)`) uses **transfer instructions** as the
counter plumbing — `$a = T_A $y` (TYA), `$y = TA $a` (TAY), `$x = TX $y` (TYX). On the 65816 the
**transfer width of TAY / TYX / TAX is governed by the X flag**, but `requiredXWidth()` treats all
transfers as `XW_None` (X-agnostic). So:

- **Bail path (`placeLegacy`, correct by accident):** a `sep #$10` at the loop *bottom* every
  iteration forces Y's high byte to 0. `TYX` then propagates a clean `0x00YY` into X → small,
  correct `arr` index.
- **Dataflow path (this fix → X16 held across the back-edge):** Y's high byte is never cleared.
  With `M=8` but `X=16`, `$y = TA $a` (TAY) does a 16-bit A→Y, dragging the hidden **B-accumulator**
  garbage into `Y.high`; `$x = TX $y` (TYX) then propagates `0xBBYY` into X → **out-of-range `arr`
  index** → wrong stored value (`xy16@MAME` mismatch).

The MIR diff (commit-1 vs this fix) is exactly the loop-mode hoist: the `rep #$10`/`sep #$10` pair
moves from inside `bb.1` (per-iteration) to the preheader/exit — the intended Increment-2
optimization, *unsafe* here only because the transfers silently depend on X.

**Therefore seed-31's fix is blocked on first fixing the transfer-instruction X-annotation** (the
hang-fix plan's *Deferred* item #2). Once `requiredXWidth()` (and/or selection) models the X-flag
dependence of `TAY`/`TYA`/`TAX`/`TXA`/`TYX`/`TXY` correctly — e.g. forcing the loop body to clear
`Y.high` when it must, or annotating the transfers so the lattice keeps the mode honest — this
`B.begin()` change becomes safe to re-land. (It is also possible the transfer fix alone makes the
*dataflow* path correct for seed-160 independent of this change; verify both together.)

---

## Verification

1. seed-31 resolves — all four oracles agree:

```
$ dev/run.sh fuzz 1 31
```

```
==> a16 differential fuzz: 1 program(s), seeds 31..31
    toolchain=/work/build/llvm-mos-install/bin  bsnes=yes
  [ ok ] seed    31  0x0B1F (all agree)
==> fuzz: 1/1 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

   **PASS** — `0x0B1F`, all four oracles agree (was `xy16@MAME=0x0CCC`).

2. Fuzz 50 — target 50/50, 0 mismatch, 0 new-crash:

```
$ dev/run.sh fuzz 50 1
```

```
  [ ok ] seed    49  0x0000 (all agree)
  [ ok ] seed    50  0xEAD4 (all agree)
==> fuzz: 50/50 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

   **PASS (50/50) on the original baseline — but NOT sufficient.** A wider sweep
   `dev/run.sh fuzz 200 1` → **195/200** (2 mismatch, 3 new-crash) revealed failures in the
   previously-untested 51–200 range. Bisect against the bail toolchain (revert just this Step-3a
   change, rebuild, re-run):

   | seed | bail (commit-1) | B.begin (this fix) | verdict |
   |---|---|---|---|
   | 31 | FAIL (mismatch) | PASS | this fix **fixes** |
   | 157 | FAIL (xy16=0x5555) | FAIL (mismatch) | **pre-existing** xy16 bug (fails both) |
   | 160 | **PASS** (0x1381) | **FAIL** (mismatch) | this fix **REGRESSES** ⚠️ |
   | 169/173/196 | crash | crash | **pre-existing** `$p`-spill crash (fails both, pre-REPSEP) |

   **FAIL — net regression.** Trading seed-31 (fixed) for seed-160 (regressed) is not acceptable
   (count is even, but a passing seed must never start failing). **Reverted.** See *§Why this is
   blocked*.

3. No regression on the existing suite:

```
$ dev/run.sh corpus && dev/run.sh xy16basic && dev/run.sh xy16spill \
    && dev/run.sh xy16spillr && dev/run.sh xy16ops
```

```
==> corpus: 7/7 passed
RESULT: PASS — +mos-xy16 accepted, X-flag lattice inert for M16-only ops, corpus_result==0x0042   (xy16basic)
RESULT: PASS — Ac16 static-stack spill compiles clean under +mos-xy16 (Layer 4 Ac16 path intact)   (xy16spill)
RESULT: PASS — LDXImag16+LDAbsXIdx16 indexed access under +mos-xy16; corpus_result==0x3457; both emulators agree   (xy16spillr)
RESULT: PASS — G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 B2 path under +mos-xy16; corpus_result==0x2A42; both emulators agree   (xy16ops)
```

   **PASS** — 7/7 corpus + all four xy16 tests green; no regression.

4. `-verify-machineinstrs` clean on seed-31 under `+mos-xy16`:

```
# build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
#   -Xclang -target-feature -Xclang +mos-xy16 -Os -mllvm -verify-machineinstrs \
#   -c /tmp/s31.c -o /tmp/s31.o
EXIT 0 — verify clean
```

   **PASS** — exit 0, no MIR verifier complaints.

5. Post-REPSEP MIR spot-check: end of `bb.0` no longer carries `SEP_Immediate 48`/`16`; `$x16`
   flows into `bb.1` in 16-bit mode; the X16→X8 transition for `bb.3` lands at `bb.3.begin()`.

```
bb.0:
  ... REP_Immediate 16; $x16 = LDXAbs16 @arr+8; REP_Immediate 32; ... BR %bb.2
                                              ; ← no end-of-block SEP: X stays 16-bit
bb.1:  liveins: $rs11, $x16                   ; $x16 live-in, still 16-bit
  SEP_Immediate 32                            ; M→8 ONLY (CPXImm16 needs M8, X16); X untouched
  renamable $c = CPXImm16 killed renamable $x16, 128   ; reads full 0x3C7D ✓
  BR %bb.3
bb.3:  predecessors: %bb.1, %bb.2
  SEP_Immediate 48                            ; sep #$30 at B.begin() — one entry switch
                                              ;   coercing both in-edges X16→X8 / M16→M8
```

   **PASS** — `bb.0` ends in X16 (no truncating `sep`); `$x16` is live into `bb.1` at full width;
   the critical-edge X16→X8 transition is a single `sep #$30` at `bb.3`'s entry, exactly as
   designed.

6. Patch sanity after `dev/regen-patch.sh`:

```
$ grep -c 'legalizeICmp\b\|addSub16Native\b' patches/llvm-mos/0002-321-accum16.patch   # expect 5
5
```

   **PASS** — foreign-hunk count 5 (unchanged); `dev/regen-patch.sh` round-trips
   (reapplied MOS dir == live vendor); the diff vs the prior commit is confined to
   `MOSInsertREPSEP.cpp` (+62/−14), no `.td` or other-file hunks absorbed.

---

## Notes / risks

- Larger fuzz sweep (`dev/run.sh fuzz 200 1`) after the fix to catch any newly-exposed shape, the
  way seed-31 surfaced once the hangs cleared.
- Consider a dedicated micro-test (`examples/65816/xy16xlive.c`) that forces a 16-bit X value
  live across a critical edge, so the regression is pinned independent of fuzzer seed numbering.
  The fuzzer (seed 31) is the immediate regression guard.
