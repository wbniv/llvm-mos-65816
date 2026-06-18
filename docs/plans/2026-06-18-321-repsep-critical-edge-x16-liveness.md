# Plan: REPSEP Critical-Edge Bail Truncates Cross-Block-Live X16 (seed-31)

**Date:** 2026-06-18
**Issue:** #321, ROADMAP M2
**Prereq:** `2026-06-18-321-xy16-hang-fix-xhigh.md` (XHigh + `requiredXWidth` pseudo fix) — landed;
took fuzz 16/50 → 49/50, cleared all 34 hangs.
**Baseline:** `dev/run.sh fuzz 50 1` → **49/50**, the single residual is seed-31, a *mismatch*
(`xy16@MAME=0x0CCC` vs expected `0x0B1F`), **not** a hang.

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

## Verification

1. seed-31 resolves — all four oracles agree:

```
$ dev/run.sh fuzz 1 31
```

   (empty)

   PASS / FAIL

2. Fuzz 50 — target 50/50, 0 mismatch, 0 new-crash:

```
$ dev/run.sh fuzz 50 1
```

   (empty)

   PASS (50/50) / PARTIAL / FAIL

3. No regression on the existing suite:

```
$ dev/run.sh corpus && dev/run.sh xy16basic && dev/run.sh xy16spill \
    && dev/run.sh xy16spillr && dev/run.sh xy16ops
```

   (empty)

   PASS / FAIL

4. `-verify-machineinstrs` clean on seed-31 under `+mos-xy16`:

```
# build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
#   -Xclang -target-feature -Xclang +mos-xy16 -Os -mllvm -verify-machineinstrs \
#   -c /tmp/s31.c -o /tmp/s31.o
```

   (empty)

   PASS / FAIL

5. Post-REPSEP MIR spot-check: end of `bb.0` no longer carries `SEP_Immediate 48`/`16`; `$x16`
   flows into `bb.1` in 16-bit mode; the X16→X8 transition for `bb.3` lands at `bb.3.begin()`.

   (empty)

   PASS / FAIL

6. Patch sanity after `dev/regen-patch.sh`:

```
$ grep -c 'legalizeICmp\b\|addSub16Native\b' patches/llvm-mos/0002-321-accum16.patch   # expect 5
```

   (empty)

   PASS / FAIL

---

## Notes / risks

- Larger fuzz sweep (`dev/run.sh fuzz 200 1`) after the fix to catch any newly-exposed shape, the
  way seed-31 surfaced once the hangs cleared.
- Consider a dedicated micro-test (`examples/65816/xy16xlive.c`) that forces a 16-bit X value
  live across a critical edge, so the regression is pinned independent of fuzzer seed numbering.
  The fuzzer (seed 31) is the immediate regression guard.
