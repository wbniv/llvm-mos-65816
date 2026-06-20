# #321 fix: a16 `G_MERGE_VALUES` 4×s8→s32 legalizer gap (Csmith seed 113)

**Target:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`. Found by the Csmith Phase-4 sweep
(seeds 101–300): **seed 113** crashes the `+mos-a16` LTO codegen. Extends the prior s32 work
([s32 plan](2026-06-19-321-a16-unmerge-s32-legalizer.md), which handled s32↔**s16**).

## The bug

```
LLVM ERROR: unable to legalize instruction:
  %1153:_(s32) = G_MERGE_VALUES %961:_(s8), %1158:_(s8), %1158:_(s8), %1158:_(s8)  (in function: main)
```
Under `+mos-a16`, s16 is legal, so s32 is represented as 2×s16 and the prior fix made `G_MERGE_VALUES {S32,S16}`
(2×s16→s32) legal. But a **direct 4×s8→s32 merge** (`{S32, S8}`, e.g. an `i8`→`i32` sign-extend the artifact
combiner couldn't fold) hits `B.unsupported()` (`MOSLegalizerInfo.cpp:149`) → abort. Default codegen is
unaffected (no S32 type; everything narrows to s8). Arises only at **LTO** (cross-TU inlining/opt produces the
surviving merge); minimal C / per-TU IR does not reproduce — repro is the deterministic Csmith seed.

`selectMergeValues` (`MOSInstructionSelector.cpp:2092`) handles only a **2-source** merge (`getFirst3Regs`
Lo/Hi → 16-bit), so making `{S32,S8}` simply *legal* would mis-select (drop 2 of 4 bytes). The fix must be in
the **legalizer**.

## Fix

Rewrite the 4×s8→s32 merge into the **already-legal 2-level form** in a custom legalizer action:
`merge(a,b,c,d:s8) → merge( merge(a,b)→s16, merge(c,d)→s16 )→s32`. Both halves are legal
(`{S16,S8}` legalForCartesianProduct; `{S32,S16}` legalFor under a16), and the artifact combiner folds them
against any feeding unmerges — same machinery the prior fix relied on.

- `MOSLegalizerInfo.cpp` G_MERGE_VALUES builder: under `hasAccum16()`, add `.customFor({{S32, S8}})`
  (alongside the existing `.legalFor({{S32, S16}})`), before `.unsupported()`.
- `legalizeCustom` dispatch: `case G_MERGE_VALUES: return legalizeMergeS32FromBytes(Helper, MRI, MI);`.
- New handler builds the two s16 sub-merges + the s32 merge, erases the original. (Only ever reached for the
  `{S32,S8}` 4-way case — `customFor` restricts the type pair.)

Gated on `hasAccum16()` → default untouched. Conservative: only adds a legal rewrite for a currently-aborting
shape; cannot regress anything that compiled before.

**Symmetry watch:** the mirror `G_UNMERGE_VALUES {S8, S32}` (s32→4×s8) is still `unsupported`. seed 113 did not
hit it (the legalizer aborts at the first failure). If a later sweep hits it, apply the symmetric custom
(`unmerge s32→2×s16, then each →2×s8`). Not added speculatively.

## Regression guard

- **Primary (deterministic):** `dev/run.sh fuzz --gen csmith 1 113` must compile/link clean and agree 4-way
  (`host==default==a16==xy16`, both emulators) — the repro that found it.
- **Sweep:** the seeds 101–300 sweep re-runs with the crash gone (was `1 crash`).
- Hermetic `.ll`: the crash is an LTO-only artifact (6.3k-line precodegen module; minimal C / per-TU IR do not
  reproduce, and `llvm-reduce`/`llvm-extract` are not built in the distribution). Deferred — the deterministic
  Csmith seed is the gate, consistent with the project's differential-first bar. (Revisit if `llvm-reduce` is
  built; then freeze a minimized fixture like `a16unmerge.ll`.)

## Verification (run each; paste raw output + PASS/FAIL on execution)

1. **Build:** `dev/run.sh toolchain` — fresh `clang-23` mtime.
2. **Crash fixed:** `dev/run.sh fuzz --gen csmith 1 113` → PASS (was: `unable to legalize … G_MERGE_VALUES
   … s8,s8,s8,s8`).
3. **No regression in the s32 family:** `dev/run.sh a16unmerge` (hermetic s32↔s16 gate) still PASS.
4. **Sweep clean:** re-run `dev/run.sh fuzz --gen csmith 200 101` → 0 crash (was 1); the seed-247 xy16
   mismatch is separately XFAIL'd/handed off (not this fix).
5. **Non-breaking:** a16 suite green; `dev/run.sh fuzz 50 1` 0 mismatch.
6. **Patch round-trips:** `dev/regen-patch.sh`; staged set is exactly my files; `0002` no foreign hunks.

## References

- Csmith fuzzer [`2026-06-19-321-csmith-differential-fuzzer.md`]; prior s32↔s16 fix
  [`2026-06-19-321-a16-unmerge-s32-legalizer.md`] (`a16unmerge.ll` precedent). Code:
  `MOSLegalizerInfo.cpp` G_MERGE_VALUES `:144`, `legalizeCustom` `:509`; `selectMergeValues`
  `MOSInstructionSelector.cpp:2092`.
