# Honor gcc `dg-require-effective-target` in the c-torture Phase-0 filter (close the oracle gap)

**Date:** 2026-06-19 · **Status:** **DONE.** `pr7284-1` reclassified to unsupported (`dg-require-unsupported`,
int32plus); in-scope 1253→1228 (58 dg-require-unsupported); `xfails.tsv` row removed. Harness-only.
**Issue:** #321, ROADMAP M2.
**Required reading:** [c-torture differential suite plan](2026-06-19-321-c-torture-execute-differential-suite.md)
(the oracle-gap caveat) · `examples/65816/torture/xfails.tsv` (the `pr7284-1` FALSE-POSITIVE row).

## TL;DR

The differential oracle is "the default (non-a16) build self-checks PASS." That is necessary but **not
sufficient**: a test that relies on undefined behavior our target resolves differently — e.g. a 32-bit-`int`
assumption — can pass the default build *by UB-luck* and then "fail" `+mos-a16` as a **false positive**.
`pr7284-1.c` is exactly this: it carries `/* { dg-require-effective-target int32plus } */` and shifts
`n << 24`, which is UB on our 16-bit `int`. gcc's `dg-require-effective-target` directive is the test
author's own declaration of what the target must provide; honoring it in the Phase-0 filter
(`tools/torture_filter.py`) cleanly excludes such tests as **unsupported** (target-inappropriate) instead of
admitting them as in-scope where they masquerade as defects.

## Scope — which effective-targets to deny (conservative)

Deny **only** requirements our 16-bit-`int` target provably cannot satisfy, so a misclassification can only
ever *skip a target-inappropriate test*, never drop a valid one:

| requirement | survey count | satisfy? | action |
|---|---|---|---|
| `int32plus` | 56 | **no** — our `int` is 16-bit | **DENY** |
| `int128` | 2 | **no** — no `__int128` | **DENY** |
| `label_values`, `indirect_jumps`, `indirect_calls` | 19/11/1 | **yes** — computed goto works (proven: `20071210-1` passes after the frame-index fix) | keep |
| `alloca`, `trampolines`, `untyped_assembly`, `return_address`, `fileio`, `mmap`, … | — | unknown / capability | keep (a non-building one is already caught by the compile/link filter) |
| `double64plus`, `longlong64`, `int32` | 2/1/1 | uncertain (`double`/`long long` width) | keep (don't over-deny; revisit only if one shows up as a false positive) |

`DENY = {int32plus, int128}` — the unambiguous integer-width family. The set is a named constant so it is
trivially extensible if a future false positive points at another requirement.

## Implementation

In `tools/torture_filter.py`, add a `dg-require` pre-check at the **top of `build_one`** (before the build):
read the test source, scan for `{ dg-require-effective-target <T> }`, and if any `<T>` is in the deny set,
return `(name, "dg-require-unsupported", "requires <T> (16-bit-int target cannot satisfy)")` — bucketed like
the other `unsupported` reasons, counted, never silently dropped. (Parsing is a cheap regex on the file
text; no compile needed for the denied case.)

Then re-run the filter to regenerate `inscope.tsv` / `unsupported.tsv`, and remove the now-out-of-scope
`pr7284-1` row from `xfails.tsv`.

## Verification (the contract — paste raw output + PASS/FAIL)

1. **Parser detects the directive.** `pr7284-1.c` → DENY (int32plus); `20071210-1.c` (label_values,
   indirect_jumps) → keep; tests with no directive → keep.
   ```
     pr7284-1.c       requires=['int32plus']                -> DENY (int32plus)
     20071210-1.c     requires=['label_values', 'indirect_jumps'] -> keep
     pr49419.c        requires=[]                           -> keep
   ```
   PASS.

2. **Re-filter partitions deterministically + `pr7284-1` leaves in-scope.**
   ```
   ==> 1228/1656 in-scope, 428 unsupported
         compile-error    170
         dg-require-unsupported 58
         link-other       26
         region-overflow  2
         undefined-symbol 172
   pr7284-1 in inscope? 0 ; in unsupported? 1 — "requires int32plus (16-bit-int target cannot satisfy)"
   sum: 1228 + 428 = 1656
   ```
   PASS — in-scope 1253→1228 (58 dg-require-unsupported; 27 int32plus tests moved off the compile-error
   bucket too, 197→170); deterministic partition.

3. **`xfails.tsv` row removed, gate consistent.** `pr7284-1` removed; caveat updated to "honored". Remaining
   rows are exactly the real defects: `pr49419`, `20041011-1`, `doloop-1`, `va-arg-22` (+ the newly-surfaced
   `k_isort` xy16, tracked separately, not a torture row).
   ```
   xfails.tsv data rows: pr49419.c, 20041011-1.c, doloop-1.c, va-arg-22.c   (4; was 5)
   ```
   PASS.

4. **Non-breaking.** Harness-only — no `vendor/llvm-mos` / `0002` change. Edits: `tools/torture_filter.py`,
   the regenerated `inscope.tsv`/`unsupported.tsv`, and `xfails.tsv`.
   ```
   git diff --cached --name-only: tools/torture_filter.py, examples/65816/torture/{inscope,unsupported,xfails}.tsv, docs/plans/..., TODO.md
   ```
   PASS.

## Risks / scoping
- **Coverage trade-off:** denying `int32plus` drops the in-scope count by however many int32plus tests were
  in-scope. That is correct — those tests are target-inappropriate by their author's own `dg-require` — but
  state the new in-scope number, don't imply lost coverage is a regression.
- **Conservative deny set:** only the provably-unsatisfiable integer-width requirements; ambiguous ones
  (`double64plus`, `longlong64`) are kept to avoid dropping a test we might validly run.

## References
- gcc effective-target keywords — <https://gcc.gnu.org/onlinedocs/gccint/Effective-Target-Keywords.html>
- The oracle-gap caveat — [`xfails.tsv`](../../examples/65816/torture/xfails.tsv) header + the suite plan.
