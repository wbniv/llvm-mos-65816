# Patch 0033: spill hoisting versus target hooks that mint virtual registers

**Independent audit and response, September 23.** The
[audit](0033-review-audit.md) confirms the crash and the guard. Each finding,
checked against the artifacts:

1. **"The cross-target run used an unpatched compiler" — not confirmed.**
   `xtarget-hoist.sh` ran inside the container, where
   `build/0029-cross-target-build` is a bind mount of `build/newton-postra-build`
   (the guarded build; `llc-hoist-fix` was copied from it at 06:41, the lit
   results are from 06:51). The 75 helper-tool failures also identify that build:
   Codex's host directory of the same name has had `split-file` since
   September 22. The run did exercise the guard, but the path alias made the
   record ambiguous, and the audit's standalone run (11,436 pass, 23 expected
   failures, 0033 alone) is the evidence the PR draft now cites. Lesson: name
   the mounted build directory in the record, not the container path.
2. **Rollback statistic — confirmed, fixed.** `--NumSpills` sat in the
   per-instruction rollback loop while `++NumSpills` counted hook calls. The
   revision counts accepted hook calls in a per-group `NumHoisted` and adds it to
   `NumSpills` only once the group is kept; rollback no longer touches the
   statistic. No MOS input reaches a mixed multi-instruction rollback (the
   audit's finding too), so `-stats` "Number of spills inserted" is identical on
   the reduced test, `950714-1` and `arith-rand` (1, 1, 23); the fix is by
   inspection.
3. **"Every corpus function is on the soft stack" — confirmed wrong.** `llc -O2
   -stop-before=irtranslator` on a leaf function adds `nonreentrant` (0 at
   `-O0`); `MOSNonReentrant` runs in `llc`. The draft's sentence is gone.
4. **Standalone vs stacked — confirmed.** With 0033 alone, `ashrdi-1` at `-O2`
   and `-Os` reaches `expected N to be free when saving scavenger register`
   (0011's defect); the draft now states the two builds separately.
5. **Downstream detail in the PR draft — accepted.** Codex's rewrite of the
   draft is kept, with the accounting revision added.

The test comment keeps its one-line provenance ("Reduced with llvm-reduce from
gcc.c-torture/execute/950714-1.c"): upstream tests routinely record their
origin, and the comment contract targets change narrative, which the rest of
the comment does not contain. The revised patch applies to the newer
`~/llvm-mos` clone and passes the comment-history check.

Revalidation of the revision (assertion build `build/0030-claude-review/llc-final`, stacked
with 0011/0030/0031/0032/0034/0036/0037):

| Check | Result |
|---|---|
| Regression test, hoisting on / `-disable-spill-hoist` | PASS / PASS |
| `-stats` "Number of spills inserted", previous accounting vs revision, three inputs | identical (1, 1, 23) |
| MOS CodeGen + MC | 141 pass, 1 unsupported, 0 fail |
| X86 + ARM + AArch64 CodeGen suites | 11,460 tests: 11,436 pass, 23 expectedly fail, 1 fail (the new AArch64 test, whose `i8`/`s8` CHECK spelling was corrected while the run was in flight; the AArch64 GlobalISel directory rerun on the committed content: 785/785 pass) |
| c-torture, hoisting on vs `-disable-spill-hoist`, same binary (`diff9`) | the same 16 compilations differ as in `diff5`, 0 newly failing either way (`pr92904` `-O0` timed out on the disabled side under load; 55 s standalone) |
| Project toolchain rebuilt + MAME/bsnes-jg gate | 79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail, 0 xfail |

Found 2026‑09‑23 while triaging the 79 c-torture compilations that fail on
every build: 18 of them (12 files) were `Remaining virtual register` on the
assertion build, and 9 of those files segfault the *release* compiler at `-O2`
in Machine Copy Propagation.

- [x] Root cause: greedy's `hoistAllSpills` runs after allocation and re-emits spills via `storeRegToStackSlot`; MOS's soft-stack `STStk` mints a scratch `Imag16` vreg that is then never assigned. `-disable-spill-hoist` makes all ten cases compile; the driver passes that flag on every compile.
- [x] Fix: generic guard in `hoistAllSpills` (refuse a group whose re-emitted spill introduces vregs); remove the driver's blanket flag.
- [x] Reduced regression test: `llvm/test/CodeGen/MOS/spill-hoist-scratch-vreg.ll` (49-line function from `950714-1.c` via `llvm-reduce`; two RUN lines, hoisting on and off).
- [x] Stacked MOS suites (135/1/0), corpus differential hoisting-with-guard vs hoisting-disabled, project toolchain rebuilt; emulator gate 79/79.
- [x] Initial patch committed.
- [x] Rollback accounting corrected (per-group `NumHoisted`), revalidated; the test comment keeps its provenance line (see above).

## Why `clang` never showed it

The unpatched `clang -c` driver passes `-mllvm -disable-spill-hoist` (with a
comment describing the mechanism). `llc` enables hoisting unless told otherwise.
Soft-stack spills create an Imag16 address scratch; static-stack spills of
imaginary registers can also create scratch registers. Optimized `llc` runs
`MOSNonReentrant` itself, so the absence of that attribute in frontend IR does
not imply every function uses the soft stack. The driver flag is the important
distinction between the two invocation paths.

## Results

Builds: `build/newton-postra-src` (pinned upstream + 0030, 0031, 0011, 0032,
then this change), assertion-enabled. `llc-0031-plus-0011` is the reduction's
unpatched control; `llc-hoist-fix` is the guarded stacked compiler. The corpus
differential below uses `llc-hoist-fix` on both sides and toggles
`-disable-spill-hoist`.

| Check | Result |
|---|---|
| The 10 failing IR cases (assert build, verifier) with hoisting enabled | 10/10 clean (0/10 before); `-disable-spill-hoist` also 10/10 |
| Recursion controls with soft-stack spills (`rec2`, `rec3`) | clean |
| `950714-1` at `-O2`: hoist groups refused | 2 (the rest still hoist) |
| Regression test on the pre-fix / fixed compiler | FAIL / PASS |
| MOS CodeGen + MC, assertions | 135 pass, 1 unsupported, 0 fail |
| c-torture, 1,390 × `-O0/-O2/-Os`, fixed `llc` with hoisting vs the same `llc` with `-disable-spill-hoist` | 0 new failures either way; 16 compilations differ; `.text` −4,510 bytes over those 16, none grow |
| X86 + ARM + AArch64 CodeGen suites (guarded stacked build, mounted as `/work/build/0029-cross-target-build`) | 11,459 tests: 11,436 pass and 23 expected failures after the 75 helper-tool reruns; superseded by the audit's standalone run |
| Project toolchain (vendor: guard + driver flag removed) + MAME/bsnes-jg corpus gate | 79 of 79 programs pass (host == default == +mos-a16 == +mos-xy16 on MAME and bsnes-jg), 0 fail, 0 xfail |

The reduction predicate required both "unpatched compiler asserts `Remaining
virtual register`" and "guarded compiler verifies clean". The independent audit
repeats that check against pristine upstream plus 0033 alone. Of the 18 original
corpus cases, all clear that assertion and 16 finish; `ashrdi-1` at `-O2` and
`-Os` then reaches the separate scavenger assertion handled by 0011 in the
stacked build.

Artifacts under `build/0030-claude-review/`: `diff5.py` / `diff5-results.json`
/ `diff5/` (hoisting on vs off), `hoist-reduce/` (reduction), `regalloc.log`
(the greedy trace showing `%580` minted by a hoisted `STStk`), `bisect-rvr.sh`
/ `bisect-rvr.log` (no standalone downstream patch fixes it), `suite-hoist.out`,
`lit-xtarget-hoist*.json`, `interesting-hoist.sh`.

`regalloc.log` is no longer present; the audit saves fresh reduced-input traces
under `build/0033-review-audit/`. The revision's artifacts: `build-hoist2.log`,
`suite-final.out`, `diff9.py` / `diff9-results.json`.
