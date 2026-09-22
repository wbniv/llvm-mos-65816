# Patch 0030: audit of Claude's review

Reviewed September 22, 2026. Scope: patch 0030's implementation, the sixth MIR
case added during Claude's review, and the proposed submission's evidence.
The separate follow-up is outside this review.

**Verdict:** no correctness defect found in 0030. Keep the implementation and
all six tests. Claude's code assessment is supported; its validation summary
needed corrections before being used in the PR. Those corrections are now in
the [description](../../upstream-copy-phys-reg-liveness-pr.md) and
[preview](0030-pr-preview.html). The subsequently supplied Claude attribution
now records CLI `2.1.278`, model `claude-fable-5-1`, and `high` reasoning effort.

## Findings in the review and submission

1. **P2 — incorrect corpus denominator and failure accounting.**
   `build/0030-claude-review/diff-results.json` has 1,656 file records, not
   1,862. At each of three optimization levels, Clang accepts 1,390 files and
   rejects 266; the claimed 1,596 accepted files is incorrect. The four
   candidate-only failures are assertion differences, not five new failures.
   `strlen-4.c` fails on both compilers, with different diagnostics. The PR's
   phrase “the five remaining failures” also omitted another 75 pairs that
   fail on both sides. The corrected accounting is below.
2. **P2 — the reused build directory does not identify standalone 0030.**
   `build/newton-postra-src` and `build/newton-postra-build` now contain the
   follow-up too. The review's successful MC log used that stacked build;
   it was not standalone 0030 evidence. The original five-case 0030 CodeGen
   result remains valid. To remove ambiguity, this audit reconstructed the
   pinned MOS tests, applied the exact current 0030 patch, and reran both MOS
   suites using the saved 0030-only binary. The new run passes.
3. **P3 — process and attribution details are incomplete.**
   The review says its changes were committed, but the patch, review and PR
   draft remain untracked at audit time. It names `dev/pr-preview-files.py`,
   whereas the supplied helper is `dev/pr-preview.py`. At audit time, Claude's
   attribution omitted the CLI version; the updated attribution now supplies
   `2.1.278`. This records the supplied version, rather than inferring it from
   the older local Claude session metadata. The process discrepancies do not
   affect the fix and are not evidence of a completed commit.

## Code assessment

`getRegWithVal` selects a register only after its existing clobber checks.
Once selected, clearing kills across `[establishing copy, insertion point)`
matches the extended live range. Including the establishing copy handles its
own killed source; excluding the insertion point leaves the pseudo being
expanded outside the walk. `clearRegisterKills(Reg, TRI)` checks register
overlap, so subregister kills are covered. The walk changes operand flags
without inserting or erasing instructions, so it does not invalidate the
backward search's iterator.

The added repeated-reuse case is useful: both later imaginary-register copies
reuse Y, and the second scan crosses the first emitted store. It preserves an
unrelated accumulator kill as well. This is an extension of the existing
regression, not a reason to change the implementation.

The patch does not change reuse selection or emit different instructions in
this helper. The assembly comparison supports unchanged output for the
sampled successful compilations; it is not a proof about every program or a
runtime test.

## Fresh standalone checks

Base: `742d554bf08042b8df93d791c335260fadd16643`.
Current patch SHA-256:
`4d3aca874ca47b5e09b805767103391836c1e44dbb2536d926e0b72cff939dfd`.
Its C++ output exactly matches the original implementation's recorded hash,
`2fb41dea87daca0502ddcecef83e4a3be40d156cafdcec867f16e0b6707921e8`;
the patch revision adds only the sixth MIR case.

| Check | Pristine, assertions enabled | 0030 only, assertions enabled |
| --- | --- | --- |
| Y reuse after kill | Verifier and FileCheck reject | Both pass |
| A reuse after kill | Verifier and FileCheck reject | Both pass |
| Overlapping subregister kill | Verifier passes; FileCheck rejects | Both pass |
| Kill on establishing copy | Verifier and FileCheck reject | Both pass |
| Clobbered-value control | Both pass | Both pass |
| Repeated reuse | Two undefined-register diagnostics; FileCheck rejects | Both pass |
| Complete MOS CodeGen | Not rerun | 84 pass, one unsupported |
| Complete MOS MC | Not rerun | 46 pass |

For a baseline case rejected by the verifier, FileCheck is run separately on
output emitted without the verifier. These are six cases in one lit test,
not six extra tests in the suite count. The unsupported test remains
`getchar-regression.ll`.

Binary hashes:

- `build/0030-claude-review/llc-pristine-assert`:
  `21f45c5b1cf7dbd82841995d370ce8b7511cca226c9abd21ea07b3ec934c77b3`.
- `build/0030-claude-review/llc-0030-only`:
  `72b2ebb80c9dc2ecda60402f7544a26606d711d974bab4b849932d39e8d168e1`.

The suite configuration points `llc` at the saved 0030-only binary. Its tests
come from a fresh archive of the pinned revision plus the current patch;
the follow-up's test and changed expectations are absent. Other MOS test tools
come from the existing build. No new compiler build or runtime run is claimed.

## Corpus accounting and assertion controls

The existing corpus log compares an assertions-off pristine backend with an
assertion-enabled 0030 backend. It contains 4,170 backend comparisons:

| Outcome | `-O0` | `-O2` | `-Os` | Total |
| --- | ---: | ---: | ---: | ---: |
| Both pass, identical assembly | 1,346 | 1,360 | 1,364 | 4,070 |
| Baseline undefined-register failure, 0030 passes | 18 | 1 | 1 | 20 |
| Both fail | 24 | 28 | 24 | 76 |
| Only assertion-enabled 0030 fails | 2 | 1 | 1 | 4 |
| Backend comparisons | 1,390 | 1,390 | 1,390 | 4,170 |

All 4,070 pairs' saved assembly files were rehashed and match their logged
identical hashes. Every successful candidate hash also matches the later
corpus run's explicitly saved 0030-only baseline, supporting the attribution
of these results to 0030. The corpus was not rerun in full for this audit.

The apparent regressions were rerun from C-derived IR with both saved
assertion-enabled compilers:

- `pr91450-1.c` and `pr91450-2.c` at `-O0`: both reject remaining virtual registers.
- `bitops-1.c` at `-O2` and `-Os`: both reject remaining virtual registers.
- `strlen-4.c` at `-O0`: both hit `assertNZDeadAt`. This is one of the 76
  both-failing pairs; the assertions-off baseline instead reports an undefined
  physical register.

This confirms that the four apparent regressions and the changed `strlen-4.c`
diagnostic are pre-existing assertion failures. It does not claim all other
both-failing pairs have identical root causes; their full diagnostics were
not retained in the corpus JSON.

## Reproduction artifacts

Under `build/0030-review-audit/`:

- `audit.py`, `audit.json`: fresh patch application, implementation hash,
  binary versions/hashes, per-case MIR results, and assertion controls.
- `*.out.mir`, `*.checks.log`, `*.log`, `*.ll`: focused outputs and diagnostics.
- `corpus-audit.json`: corrected counts and saved-output hash verification.
- `suite.py`, `lit-0030.json`, `lit-0030.log`: isolated MOS CodeGen and MC run.
- `source/`, `bin/`, `test/`: reconstructed tests and their explicit tool mapping.

The host lit runner required execution outside the sandbox because Python's
multiprocessing socket was blocked. The resulting test run completed with
exit status zero. No upstream PR, comment, branch, commit, or push was made by
this audit.
