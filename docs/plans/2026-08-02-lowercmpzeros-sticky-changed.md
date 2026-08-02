# `lowerCmpZeros` sticky loop-carried `Changed` — silently dropped flag tests

**Date:** 2026-08-02 · **Status:** FIXED + VALIDATED 2026-08-02; upstream package READY TO POST (status row 18)
**Item:** TODO `[T3]` (found in passing by the #138 Phase A investigation, 2026-07-31)
**Visible surface:** none — compiler pass. No mockups.

## Defect

`MOSLateOptimization::lowerCmpZeros` (`MOSLateOptimization.cpp:90`) walks a block in reverse
and, for each `CmpZero` pseudo, either folds it into an earlier NZ producer or lowers it to a
real flag-setting instruction. The fold-success flag was the function's **loop-carried**
`Changed` accumulator:

```cpp
bool Changed = false;
for (MachineInstr &MI : make_early_inc_range(mbb_reverse(MBB))) {
  ...
  for (auto &J : mbb_reverse(MBB.begin(), MI))
    if (definesNZ(J, Val, STI)) { Changed = true; /* fold, erase */ break; }
  if (Changed)          // <-- true for EVERY CmpZero after the block's first fold
    continue;           //     even ones that did not fold
  Changed = true;
  lowerCmpZero(MI);     // <-- never reached again in this block
}
```

After the first successful fold in a block, every later-processed (= earlier in program order)
`CmpZero` is skipped instead of lowered. Nothing downstream lowers the pseudo.

## Failure mode — silent drop, no diagnostic

Measured, not inferred. Repro MIR (reverse iteration processes the *second* `CmpZero` first;
it folds, then the first is skipped):

```mir
bb.0.entry:
  liveins: $a, $x
  CmpZero $x, implicit-def $n, implicit-def $c   ; cannot fold — nothing precedes it
  $a = T_A $x
  CmpZero $a, implicit-def $n, implicit-def $c   ; folds into the T_A
  RTS implicit $n
```

`llc -run-pass=mos-late-opt` leaves `CmpZero $x` in the output, `-verify-machineinstrs` does
**not** object (the pseudo is legal MIR), and continuing to the asm printer emits **nothing at
all** for it:

```asm
cmpzero_after_fold:
	                  ; <- the surviving CmpZero emitted as empty
	txa
	rts
```

So the promised flag test disappears with no crash and no diagnostic. That is a
silent-wrong-code shape, not verifier hygiene — the severity depends only on whether a real
block can consume the dropped NZ before the next producer redefines it (see Verification 4).

## Fix

Make the fold flag per-`CmpZero` (`bool Folded`), leaving `Changed` as the accumulator it was
meant to be. Also set `Changed` on the `allDefsAreDead()` erase path, which mutated the
function while reporting "no change".

## Verification

1. Red/green on the repro (new lit test `late-opt-cmpzero-after-fold.mir`).
2. MOS lit suite: exactly the 7 known fork-divergence failures + the new test green.
3. Corpus differential sweep (`dev/run.sh corpus-a16`).
4. **Real-world incidence + reach**: rebuild pre/post and diff the corpus objects. Every object
   that *changes* is a place the bug was firing in shipped code; inspect one to determine
   whether the dropped test was observable (consumer of NZ before the next producer) or inert.
   Inertness here is the opposite of the usual expectation — diffs are the finding.
5. Upstream reproducibility: the pass is upstream MOS code, so check whether pristine
   `llc` (no fork features) reproduces → determines standalone-patch + PR vs fold into `0002`.


## Verification record (2026-08-02)

1. **Red/green on the repro.** Pre-fix `llc -run-pass=mos-late-opt` leaves `CmpZero $x` in the
   output and the asm printer emits an empty line for it; post-fix it lowers to
   `dead $a = T_A $x, implicit-def $nz` → a real `txa`. New lit test
   `late-opt-cmpzero-after-fold.mir` PASSES. **PASS**
2. **MOS lit suite.** 83 tests, 7 failures = exactly the known fork-divergence set
   (`indexiv`, `indvar-simplify-20230930`, `leaf-20231021`, `legalizer.mir`, `nonreentrant`,
   `nonreentrant-nointerrupts`, `shift-rotate`); the new test is green. **PASS**
3. **Corpus differential** (`JG_ONLY=1 dev/run.sh corpus-a16`). The run was **OOM-killed at row
   8 of 61** — this box has **no swap** and seamdemo P3's emulator gate was running
   concurrently (same failure mode the PH-$p work documented; exit 137). Of the 8 rows that
   completed, **8/8 have `host == a16@bsnes`** and **0 genuine value mismatches**; every row's
   `FAIL` label is the missing-SPC700-BIOS artifact (`*@MAME=None`), not a value disagreement.
   **PARTIAL PASS — 8/8 completed rows agree; full sweep to be re-run when the box is idle.**
4. **Real-world incidence + reach.** 140 files × 4 configs (`-O1/-O2/-Os`, with and without
   `+mos-a16`), 17,403 basic blocks scanned via `-print-before=mos-late-opt`: **maximum 1
   `CmpZero` per block, zero blocks meet the ≥2 precondition.** The fix is therefore inert for
   this tree — which is also why no demo ever caught it — and no object-diff evidence of the
   bug firing in shipped code exists or can exist here. Reach: latent, mechanism proven by
   construction. **PASS (zero incidence)**
5. **Upstream reproducibility.** `build/upstream-llc` (pristine `8be0546128a5`, no fork
   features) leaves the same survivor on the same MIR → genuine upstream defect. Carried as
   standalone patch `0022` (wired into `dev/toolchain.sh`, baked into `regen-patch.sh`'s
   `BASELINE_MOSDIR`), PR package drafted in
   [upstream-late-opt-cmpzero-lowering-pr.md](../upstream-late-opt-cmpzero-lowering-pr.md);
   posting is user-triggered. **PASS**
