# Patches 0034 and 0035: `__builtin_prefetch` on MOS

Two defects behind the 18 c-torture compilations (`builtin-prefetch-1.c` …
`builtin-prefetch-6.c` at `-O0`, `-O2`, `-Os`) that failed on every build:

- **0034 (llvm-mos):** `G_PREFETCH` was never legalized; the backend aborted on
  any `__builtin_prefetch`. Fix: custom-legalize by erasing the instruction (a
  hint, and the 6502 has nothing to hint). [PR draft](../../upstream-prefetch-legalize-pr.md).
- **0035 (clang, for llvm/llvm-project):** with explicit rw/locality arguments,
  `__builtin_prefetch` is emitted with `i16` operands on 16-bit-`int` targets
  (MOS, MSP430, AVR), an incompatible intrinsic signature that the IR verifier
  rejects. Fix: cast the operands to `i32`. [PR draft](../../upstream-clang-prefetch-int16-pr.md).

Neither has downstream dependencies.

**Independent audit, September 23:** [0034 audit](0034-review-audit.md) finds
no implementation defect. A pristine-plus-0034 assertion build passes 130 MOS
tests, one unsupported, and legalization checks on all 14 stock CPUs at two
optimization levels; address-producing calls and volatile stores remain intact.
The historical 137-pass count below belongs to the stacked build.

The [0035 audit](0035-review-audit.md) confirms the implementation and broadens
the diagnosis: explicit options can be any accepted promoted integer type, so
`1L`/`2L` also produces invalid `i64` arguments on x86-64. The patched frontend
passes all 32 expanded cases across MOS/MSP430/AVR/x86-64; 21 baseline modules
fail verification and the 11 already-valid modules retain identical IR. Add a
committed wider-argument/two-argument regression and correct the C-`int` comments
before submitting 0035. Its destination remains `llvm/llvm-project`.

**Response, September 23:** both findings verified (`__builtin_prefetch(p, 1L, 2L)`
on x86-64 emits `i64` operands with the pinned Clang; the fixed Clang emits
`i32`). 0035 revised: the test gains `rw_only` (two-argument form), `long_args`
(`1L`/`2L`) and `long_long_args` (`0LL`/`1LL`), so the `x86_64` RUN line now
discriminates as well (pinned Clang FAIL on both triples, fixed Clang PASS on
both); the source comment describes promoted expression types and the old
`FIXME` is removed. The code is unchanged, so the fixed frontend already
implements the revision. 0034 needs no change. The revised patch applies to the
newer `~/llvm-mos` clone and passes the comment-history check.

## Results

Builds: `build/newton-postra-src` (pinned upstream plus the carried patches)
rebuilt as the assertion `llc` (`build/0030-claude-review/llc-prefetch`; the
previous binary `llc-hoist-fix` is the pre-fix control) and as the release
clang in `build/register-exhaustion-build` (`clang`).

| Check | Result |
|---|---|
| `llvm/test/CodeGen/MOS/prefetch.ll` (`-O0`, `-O2`, verifier) | pre-fix: FAIL (backend abort) · fixed: PASS |
| `clang/test/CodeGen/builtin-prefetch-int16.c` | pinned Clang: `msp430` FAIL, `x86_64` PASS · fixed Clang: both PASS |
| `builtin-prefetch-1…6.c` × `-O0/-O2/-Os`, fixed `clang -c -mllvm -verify-machineinstrs` | 18/18 clean |
| same files as IR through the assertion `llc` with the verifier | 18/18 clean; the emitted intrinsic operands are `i32` |
| MOS CodeGen + MC suites, assertion build | 137 pass, 1 unsupported, 0 fail (includes the new prefetch test) |
| Both patches apply on the newer `~/llvm-mos` clone; history-wording check | clean |
| Project toolchain rebuilt with both | rebuilt and installed; the installed clang compiles the six files at three levels with the verifier: 18/18 |

No emulator gate: neither change affects any program that does not use
`__builtin_prefetch`, and the corpus contains none.
