# #321 fix: a16 ALU/compare abs+indir load-fold must not move a load across a memory-clobbering call

**Target:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp` (`foldableAbsLoad16` +
`foldableIndirLoad16`). Found by the broad `-Os` c-torture sweep
([sweep plan](2026-06-20-321-broad-c-torture-sweep.md)) — the only 2 FAILs, `pr34768-1`/`pr34768-2`.

## The bug (root-caused 2026-06-20)

`foldableAbsLoad16` / `foldableIndirLoad16` fold a single-use, same-BB 16-bit load into the consuming ALU op
or compare as a **memory operand** (`adc abs` / `cmp abs` / `cmp (zp)`), instead of staging the value through
an `Imag16` pair. They check single-use + same-BB but **not** whether an instruction between the load and the
user clobbers the loaded memory. When a **call** (or any `mayStore`) sits between them, folding **moves the
memory read forward past the clobber**, reading a different value → miscompile.

**Witness — `pr34768-1.c`** (`int tmp = x; (c?foo:bar)(); return tmp + x;`, `foo` does `x = -x`):
- post-LTO-opt IR (identical for default & a16, **correct**):
  `%1 = load @x; call @foo(); %2 = load @x; %3 = add %2, %1`
- default `-Os` LTO asm (correct): saves `tmp=x` to zp **before** `jsr foo`, reloads `x` after, `tmp + x`.
- **a16 `-Os` LTO asm (WRONG):** `jsr foo; rep; lda x; clc; adc x; …` → `x + x`. The pre-call load `%1` was
  folded into `adc x` and re-executed **after** `foo()` modified `x`. → `test(1)` returns `-2` not `0` → the
  shim's `abort()` → `corpus_result = 0xDEAD`.

**Scope / blame:** pre-existing in `foldableAbsLoad16` (the abs-operand fold, landed well before the indexed
work); **not** caused by `9009260`. Surfaced only now because this is the **first full `-Os` torture pass**
(prior pass was `-O1`, where LTO didn't const-collapse the ternary into the straight-line `load;call;use`
shape). `foldableIndirLoad16` (added in `9009260`) shares the identical latent flaw and is fixed in the same
change. Default codegen is unaffected (it has no 16-bit abs/indir fold).

## The bar

host == default(8-bit) == `+mos-a16` == `+mos-xy16`, MAME + bsnes-jg, `-verify-machineinstrs` clean.
Governing lesson #2: the fix must be **conservative** — blocking the fold across a clobber may only ever
forgo a win, never regress a correct fold.

## Fix

In both helpers, after the existing single-use/same-BB/class checks, scan the instructions strictly between
`Def` and `User` in their common block; if any `mayStore()` or `isCall()` (or `hasUnmodeledSideEffects()`),
return `nullptr` (don't fold — stage through `Imag16` as before). Same-BB + single-use bound the scan.

```cpp
// Folding re-reads the loaded memory at User's location. If anything between the
// load and User may write memory (notably a call), that value can change -> bail.
const MachineBasicBlock *MBB = Def->getParent();
bool afterDef = false;
for (const MachineInstr &MI : *MBB) {
  if (&MI == Def) { afterDef = true; continue; }
  if (&MI == &User) break;
  if (afterDef && (MI.mayStore() || MI.isCall() || MI.hasUnmodeledSideEffects()))
    return nullptr;
}
```

Applied identically to `foldableAbsLoad16` (G_LOAD16_ABS) and `foldableIndirLoad16` (G_LOAD16_INDIR).

## Regression guard (same change)

- New micro-test `examples/65816/a16loadcall.c` + `dev/a16loadcall.sh`: the `tmp = g; clobber_g_via_noinline_call();
  return tmp + g;` shape (mirrors `pr34768`), both for an abs global and a pointer (`(zp)` indir) operand, so
  both helpers are exercised. host==default==a16, both emulators; assert the abs/indir load is **not** folded
  across the call (no `adc abs`/`cmp (zp)` after the `jsr`; a `tmp` save survives).
- `pr34768-1`/`pr34768-2` become positive `-Os` torture cases (they already PASS at `-O1`; after the fix the
  `-Os` sweep is clean — they are **not** XFAIL'd, so no ledger edit; verify they PASS).

## Verification (run each; paste raw output + PASS/FAIL on execution)

**EXECUTED 2026-06-20 — fix verified (toolchain rebuilt, `clang-23` mtime `05:24`).**

1. **Build:** `dev/run.sh toolchain` — fresh `clang-23` mtime.
   ```
   -rwxr-xr-x 1 will will 124762008 05:24 build/llvm-mos-install/bin/clang-23
   ```
   **PASS** — incremental rebuild took (only `MOSInstructionSelector.cpp` changed).
2. **The bug is fixed:** `dev/run.sh torture --tests pr34768-1.c pr34768-2.c --opt -Os` → both PASS, MAME +
   bsnes-jg.
   ```
   ==> torture-run: 2 test(s), -Os, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
        pr34768-1.c            PASS  all variants PASS (0x600D)
        pr34768-2.c            PASS  all variants PASS (0x600D)
   ==> torture-run: 2 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 2)
   ```
   **PASS** — both, on both emulators (was `0xDEAD`).
3. **The fold still fires where safe (no regression of the win):** the folds with no intervening call keep
   folding — `a16cmpidx` (disasm gate ≥5 `cmp (zp)`, 0x1111), `a16abscmp` (`cmp abs`, 0x4303), `a16loadfold`
   (`lda/adc abs`, 0x2345), `a16mixfold` (0x2DC0), `a16cmpaudit` (0x5EE0), `a16cmp` (0x1103) — all PASS both
   emulators. **PASS** — no win lost.
4. **New micro-test:** `dev/run.sh a16loadcall` → host==default==a16 both emulators.
   ```
   ==> a16loadcall: differential default vs +mos-a16  (expected 0x0100; bsnes=yes)
     [PASS] a16loadcall  0x0100 (all agree)
   ```
   **PASS** — abs + `(zp)` + compare operands all staged (not folded) across the call; `0x0100` 4-way.
5. **verify-machineinstrs:** clean — exercised by every `diff_check`/`torture` compile above (no "Bad machine
   code"). **PASS**.
6. **Non-breaking:** `dev/run.sh fuzz 50 1` + the full `-Os` torture re-sweep (`torture 1200 --start 60
   --no-bsnes`, the exact range that had 2 FAILs) → expect 0 FAIL.
   ```
   ==> csmith: 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)
   ==> torture-run: 1114 PASS, 0 FAIL, 54 SKIP, 0 XFAIL (of 1168)
        pr34768-1.c            PASS  all variants PASS (0x600D)
        pr34768-2.c            PASS  all variants PASS (0x600D)
   ```
   **PASS** — re-sweep `0 FAIL` (was 2; +2 PASS, no regression); fuzz 0-mismatch/0-crash.
7. **Patch round-trips:** `dev/regen-patch.sh`; staged set is exactly my files; `0002` no foreign hunks.
   ```
   RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
   # git diff --stat: 26 insertions / 5 deletions (noStoreBetween + 2 call sites); noStoreBetween=3
   ```
   **PASS** — committed `86c2602`.

## Risks

- **R1 (low):** the scan could mis-bail on a `mayStore` that doesn't alias the load (e.g. a spill store),
  forgoing a fold — acceptable (only forgoes a win). A precise alias check is unnecessary for correctness.
- **R2 (low):** `isCall()`/`mayStore` must cover `__call_indir` and ordinary `jsr` — both are `isCall()` in
  MIR; inline asm covered by `hasUnmodeledSideEffects()`.

## Audit — all a16 load-fold sites checked for the same hazard

Swept every load-fold site in the MOS backend for the same across-call hazard; **the two helpers fixed here
were the only vulnerable ones** (all others guard via `shouldFoldMemAccess` or explicit `isCall`/`mayStore`).
The full findings table + the "why not consolidate onto `shouldFoldMemAccess`" rationale (it bails on volatile
loads the #321 corpus folds) live in the standalone audit plan
[`2026-06-20-321-audit-a16-loadfold-call-hazard.md`]. **Bug class closed; no code change resulted.**

## References

- Sweep that found it [`2026-06-20-321-broad-c-torture-sweep.md`]; the fold helpers
  `MOSInstructionSelector.cpp` `foldableAbsLoad16` / `foldableIndirLoad16`; indexed-compare fold that shares
  the helper shape `9009260` + [`2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md`].
