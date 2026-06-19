# #321 broad c-torture sweep — run the full in-scope execute suite through the differential gate

**Target:** the in-scope gcc `c-torture/execute` set (≈1228 tests after the dg-require filter), driven through the
`+mos-a16` / `+mos-xy16` differential gate (`dev/run.sh torture`). **Bug-finding, not feature work** — the
deliverable is a green bill of health across the whole set, or a root-caused miscompile + in-backend fix +
regression test. Builds on the suite scaffolding from
[`docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md`](2026-06-19-321-c-torture-execute-differential-suite.md)
(Phase 0 host filter + Phase 1 pilot already landed; this is the Phase-2 *full execution*).

## Why now

The c-torture differential is the project's most productive bug-finder: it has cleared real defects in
clusters — `f2d65c2` (CmpBrAbsImm16 frame-index scramble) **cleared 13 miscompiles** and `55ec505` (the xy16
`requiredXWidth` index-width gap) **cleared 5**. With the indexed-compare work just landed (`9009260`) and the
xy16 X-flag lattice settled, the suite backlog (`xfails.tsv`) is reported clear — so a full sweep both
**confirms no regression from the new `CMPIndir16` fold** and **hunts for the next cluster**. This session
already ran the first **60/1230 (all PASS)**; this plan covers the remaining ~1168.

## The bar (correctness = the differential)

DEFAULT (non-`+mos-a16`, trusted 8-bit) build is the oracle. For each in-scope test:
`default@MAME == +mos-a16@MAME == +mos-xy16@MAME` (the catch-net), and any FAIL gets independent
`+mos-a16@bsnes-jg` confirmation during root-cause. A test whose DEFAULT build doesn't self-check PASS is
SKIP'd (target-inappropriate), so **any FAIL is a real #321 defect** (or a genuine a16/xy16 hang vs a
completing default — also FAIL). `-verify-machineinstrs` is exercised by the per-test compile.

## Method / scope decisions

- **MAME 3-way as the broad catch-net (`--no-bsnes`)** for speed — full set × 3 variants × 2 emulators is
  hours (suite plan, "Emulator wall-clock"). bsnes-jg confirmation is applied per-FAIL, not per-test.
- **Streamed single background run**, `dev/run.sh torture 1200 --start 60 --no-bsnes`, output to the task log
  so each result is visible incrementally (failures surface immediately; the run survives across turns).
  Resume after any interruption via `--start K`.
- **`-Os`** is the default sweep optimization (the level that exposed the `globals.c` RA crash + most folds);
  a follow-up `--opt -O1` pass is optional if `-Os` is clean.
- **No `vendor/`/`0002` edits** unless Phase 2 produces a root-caused bug — Phase 1 is pure execution.

## Phase 1 — Run the sweep — DONE 2026-06-20

`dev/run.sh torture 1200 --start 60 --no-bsnes` swept all 1168 in-scope tests at `-Os`. First run:
**`1112 PASS, 2 FAIL, 54 SKIP, 0 XFAIL`** — the 2 FAILs `pr34768-1`/`pr34768-2`, **0 XPASS churn** (the
`CMPIndir16` fold `9009260` confirmed non-regressing). Combined with the earlier first-60 run, the whole
in-scope set is covered at `-Os`.

## Phase 2 — Triage any FAIL (only if M > 0)

Per failing test, in priority order (mirror the prior cluster fixes):
1. **Confirm it's real** — reproduce default==PASS, a16/xy16!=, plus the bsnes-jg leg (`drop --no-bsnes` on
   that single test). Rule out a target-inappropriate SKIP misclassification.
2. **Minimize** — delta-debug to the smallest C trigger (a `dev/`-style micro-test), classify which variant
   (a16-only, xy16-only, both) and at which `-O`.
3. **Root-cause in the backend** — which pass / pattern (the last two were `eliminateFrameIndex` and
   `requiredXWidth`); look for a *cluster* (one fix often clears many — group by shared symptom).
4. **Fix + regression-guard in the same change** — in-backend fix in `vendor/`, regen `0002`; de-XFAIL the
   cleared rows in `xfails.tsv` **and** add an `examples/65816/` micro-test as a positive gate.

## Phase 3 — Record the verdict — DONE 2026-06-20

The 2-FAIL `pr34768` cluster was root-caused to a pre-existing a16 load-fold-across-call miscompile and
**fixed** (commit `86c2602`, citing the breaking commit `ef4671d`; see
[fix plan](2026-06-20-321-abs-load-fold-across-call-miscompile.md)). Full `-Os` **re-sweep:
`1114 PASS, 0 FAIL, 54 SKIP, 0 XFAIL`** (was `1112/2`; +2 PASS, no regression), fuzz 45/50 0-mismatch/0-crash.
Verdict: the in-scope c-torture set is **green at `-Os`** (and `-O1`), and the `CMPIndir16` fold is confirmed
non-regressing. Remaining suite work (Phase 3 sampled CI, orphan-MAME reaping) tracked under the parent
`[wip]` c-torture TODO item.

## Verification (run each; paste raw output + PASS/FAIL back here on execution)

1. **Sweep completes:** `dev/run.sh torture 1200 --start 60 --no-bsnes` → final `torture-run:` tally; record
   PASS/FAIL/SKIP/XFAIL counts.
2. **No regression from `9009260`:** 0 *new* FAIL vs the pre-sweep `xfails.tsv` baseline; no XPASS churn
   (a previously-XFAIL row now passing is good, but must be de-XFAIL'd, not left stale).
3. **Each FAIL (if any) is real:** default==PASS while a16/xy16 diverge, confirmed on bsnes-jg for the
   minimized trigger; not a SKIP misclassification.
4. **Fixes (if any) round-trip:** `dev/regen-patch.sh` PASS; `git diff --cached --name-only` is exactly my
   files; `0002` absorbs no foreign hunks; the new micro-test is green on both emulators.

## Risks

- **Wall-clock.** ~1168 × 3 variants × `-Os` ≈ 1.5–2 h. Mitigated by `--no-bsnes` + streamed background +
  `--start` resume.
- **XPASS churn from the new fold.** The `CMPIndir16` fold could flip a previously-XFAIL'd compare test to
  PASS — that's a win, but the row must be de-XFAIL'd in the same pass (Verification 2).
- **False FAIL from a flaky watchdog.** A genuine-vs-watchdog hang is distinguished by the default build:
  default completes + a16 times out ⇒ real FAIL; both time out ⇒ SKIP (suite plan, "Watchdog vs real hang").

## References

- Suite scaffolding [`docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md`]; the two prior
  cluster fixes [`…2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md`] (13 cleared) and
  [`…2026-06-19-321-xy16-xflag-lattice-fix.md`] (5 cleared); dg-require filter
  [`…2026-06-19-321-torture-honor-dg-require-effective-target.md`]. Just-landed indexed-compare fold:
  commit `9009260` + [`…2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md`].
- Runner: `dev/torture.sh` / `tools/torture_run.py`; in-scope filter `tools/torture_filter.py` →
  `examples/65816/torture/inscope.tsv`; known-issue/XFAIL ledger `xfails.tsv`.
