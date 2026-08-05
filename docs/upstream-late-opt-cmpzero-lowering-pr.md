# [MOS] `mos-late-opt`: don't skip `CmpZero` lowering after the block's first fold

<!-- ✅ POSTED 2026-08-04 as https://github.com/llvm-mos/llvm-mos/pull/589.
     Body below minus the H1 and this comment is the as-posted text.
     Branch: mos-late-opt-cmpzero-lowering @ 8c8d28b0c35a (cherry-pick repair of f8cfe68b after a
     shared-clone branch-switch race; pushed), cut from upstream
     tip 1f334fef02b5 (patch 0022 applied clean). Verified in ~/llvm-mos/build-pr:
     RED = late-opt-cmpzero-after-fold.mir FAILS without the fix on the same tree;
     GREEN = passes with it; full CodeGen/MOS suite: 79 pass, 0 failures
     (getchar-regression.ll is upstream-disabled via its own UNSUPPORTED directive). [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.]
     Post commands (user-triggered):
       git -C ~/llvm-mos push origin mos-late-opt-cmpzero-lowering
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-cmpzero-lowering --base main \
         --title "[MOS] mos-late-opt: don't skip CmpZero lowering after the block's first fold" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-late-opt-cmpzero-lowering-pr.md)
     After posting: flip the status-doc row and refresh wald3n.com's contributions snapshot
     (task open-source:refresh + task publish in ~/wald3n.com).
-->

## Summary

`MOSLateOptimization::lowerCmpZeros` walks a basic block in reverse. For each `CmpZero`
pseudo it either folds the test into an earlier NZ producer, or calls `lowerCmpZero` to
materialize a real flag-setting instruction. The flag recording "this `CmpZero` folded" was
the function's **loop-carried `Changed` accumulator**:

```cpp
bool Changed = false;
for (MachineInstr &MI : make_early_inc_range(mbb_reverse(MBB))) {
  ...
  for (auto &J : mbb_reverse(MBB.begin(), MI))
    if (definesNZ(J, Val, STI)) { Changed = true; /* fold + erase */ break; }
  if (Changed)        // true for every later CmpZero once ANY fold happened
    continue;         // ... so this one is never lowered
  Changed = true;
  lowerCmpZero(MI);
}
```

Once any `CmpZero` in the block folds, every `CmpZero` processed afterwards takes the
early `continue` and is never lowered. Nothing downstream lowers the pseudo.

## Why it is silent

A surviving `CmpZero` is legal MIR, so `-verify-machineinstrs` does not object, and the asm
printer emits **nothing** for it — no crash, no assertion, no diagnostic. The comparison the
pass promised simply disappears, leaving any consumer to branch on stale N/Z.

## Reproducer

Reverse iteration processes the second `CmpZero` first; it folds into the `T_A`, which then
suppresses lowering of the first (which cannot fold — nothing precedes it):

```mir
# llc -mtriple=mos -run-pass=mos-late-opt -verify-machineinstrs
bb.0.entry:
  liveins: $a, $x
  CmpZero $x, implicit-def $n, implicit-def $c
  $a = T_A $x
  CmpZero $a, implicit-def $n, implicit-def $c
  RTS implicit $n
```

Before this change, the pass leaves the first pseudo in place:

```
bb.0.entry:
  CmpZero $x, implicit-def $n, implicit-def $c      <-- never lowered
  $a = T_A $x, implicit-def $nz
  RTS implicit $n
```

and continuing to the asm printer (`-start-before=mos-late-opt`) emits an empty line where
the flag test should be:

```asm
cmpzero_after_fold:
	                  ; the surviving CmpZero, emitted as nothing
	txa
	rts
```

After the change the pseudo is lowered and the test is real (`txa` / `dead $a = T_A $x,
implicit-def $nz`).

## Fix

Use a per-`CmpZero` `Folded` flag for the fold decision and leave `Changed` as the
accumulator it was meant to be. Also set `Changed` on the `allDefsAreDead()` erase path,
which mutated the function while reporting "no change".

## Tests

`llvm/test/CodeGen/MOS/late-opt-cmpzero-after-fold.mir` — the two-`CmpZero` block above;
asserts both the fold and the lowering, plus `CHECK-NOT: CmpZero`. It fails before the change
(the pseudo survives) and passes after.

`llvm/test/CodeGen/MOS/` is otherwise unchanged by this patch.

## Notes on exposure

Found by inspection during an unrelated `mos-late-opt` investigation (the same pass read that
produced [#584](https://github.com/llvm-mos/llvm-mos/pull/584)), not by a miscompile in the
wild. Measured incidence in the reporter's tree: across 140 source files × 4 configurations
(17,403 basic blocks, `-O1/-O2/-Os`, with and without a 16-bit-accumulator target feature) the
maximum number of `CmpZero` pseudos in any single block is **1**, so the precondition never
occurred there. The scan methodology and raw numbers are recorded in the
[investigation write-up](https://github.com/wbniv/llvm-mos-65816/blob/main/docs/plans/2026-08-02-lowercmpzeros-sticky-changed.md)
(`-print-before=mos-late-opt` over the corpus). The mechanism is nonetheless reachable by
construction, and the failure mode is silent, so it seems worth fixing rather than waiting for
a shape that triggers it.
