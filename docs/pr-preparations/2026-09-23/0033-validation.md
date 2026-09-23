# Patch 0033: spill hoisting versus target hooks that mint virtual registers

Found 2026‑09‑23 while triaging the 79 c-torture compilations that fail on
every build: 18 of them (12 files) were `Remaining virtual register` on the
assertion build, and 9 of those files segfault the *release* compiler at `-O2`
in Machine Copy Propagation.

- [x] Root cause: greedy's `hoistAllSpills` runs after allocation and re-emits spills via `storeRegToStackSlot`; MOS's soft-stack `STStk` mints a scratch `Imag16` vreg that is then never assigned. `-disable-spill-hoist` makes all ten cases compile; the driver passes that flag on every compile.
- [x] Fix: generic guard in `hoistAllSpills` (refuse a group whose re-emitted spill introduces vregs); remove the driver's blanket flag.
- [x] Reduced regression test: `llvm/test/CodeGen/MOS/spill-hoist-scratch-vreg.ll` (49-line function from `950714-1.c` via `llvm-reduce`; two RUN lines, hoisting on and off).
- [x] Suites (MOS 135/1/0; X86/ARM/AArch64 clean), corpus differential hoisting-with-guard vs hoisting-disabled, project toolchain rebuilt; emulator gate in progress at commit time.
- [x] Commit. Publish (user-triggered).

## Why `clang` never showed it

`clang -c` passes `-mllvm -disable-spill-hoist` (with a comment describing this
exact mechanism and deferring the fix). `llc` on the same IR has hoisting on.
In addition, functions only use the soft stack when they are not marked
`nonreentrant` (or at `-O0`), so in a real compile only recursive or reentrant
functions can reach the hoisted-spill path; in an `llc` run of Clang's IR every
function does, which is why the corpus exposed it.

## Results

Builds: `build/newton-postra-src` (pinned upstream + 0030, 0031, 0011, 0032,
then this change), assertion-enabled; `build/0030-claude-review/llc-0031-plus-0011`
is the last binary without it and `llc-hoist-fix` the first with it.

| Check | Result |
|---|---|
| The 10 failing IR cases (assert build, verifier) with hoisting enabled | 10/10 clean (0/10 before); `-disable-spill-hoist` also 10/10 |
| Recursion controls with soft-stack spills (`rec2`, `rec3`) | clean |
| `950714-1` at `-O2`: hoist groups refused | 2 (the rest still hoist) |
| Regression test on the pre-fix / fixed compiler | FAIL / PASS |
| MOS CodeGen + MC, assertions | 135 pass, 1 unsupported, 0 fail |
| c-torture, 1,390 × `-O0/-O2/-Os`, fixed `llc` with hoisting vs the same `llc` with `-disable-spill-hoist` | 0 new failures either way; 16 compilations differ; `.text` −4,510 bytes over those 16, none grow |
| X86 + ARM + AArch64 CodeGen suites (generic change) | 11,459 tests: 11,361 pass, 23 expectedly fail, 0 fail (75 first-pass failures were unbuilt helper tools in that build directory: split-file, llvm-dwarfdump, llvm-as, llvm-profdata, llvm-nm, llvm-cgdata, llvm-lto2; all 75 pass once built) |
| Project toolchain (vendor: guard + driver flag removed) + MAME/bsnes-jg corpus gate | 76 of 79 programs pass, 0 fail; run still in progress at commit time, final figure to follow |

The reduction predicate required both "old compiler asserts `Remaining virtual
register`" and "new compiler verifies clean", so the test pins the mechanism,
not merely a crash.

Artifacts under `build/0030-claude-review/`: `diff5.py` / `diff5-results.json`
/ `diff5/` (hoisting on vs off), `hoist-reduce/` (reduction), `regalloc.log`
(the greedy trace showing `%580` minted by a hoisted `STStk`), `bisect-rvr.sh`
/ `bisect-rvr.log` (no standalone downstream patch fixes it), `suite-hoist.out`,
`lit-xtarget-hoist*.json`, `interesting-hoist.sh`.
