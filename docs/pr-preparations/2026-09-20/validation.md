# Validation — 2026-09-20

MVN/MVP upstream base: `742d554bf08042b8df93d791c335260fadd16643`.
Prepared local commit: `ae3108c3189076607b12fd5ff514a21678df8c8b`.
MVN/MVP published as [compiler PR #604](https://github.com/llvm-mos/llvm-mos/pull/604); head and submitted description verified.
SDK longjmp was separately published as SDK PR #450.

## MVN/MVP

Fresh MOS-only Release tools with assertions enabled were built using clang and lld
in `llvm-mos-65816-dev`. Source checkout: `/tmp/llvm-mos-next-prs`; build:
`/tmp/llvm-mos-next-build`. CMake settings include
`LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=MOS`, empty `LLVM_TARGETS_TO_BUILD`,
`LLVM_ENABLE_ASSERTIONS=ON`, `LLVM_INCLUDE_BENCHMARKS=OFF`.

The [regression](65816-block-move-bank-order.s) contains executable RUN lines for
encoding, disassembly, fixup offsets, ELF relocations, and forward-defined constants.

| Tools/source | Encoding | Disassembly | Fixups | Relocations | Resolved constants |
|---|---|---|---|---|---|
| Fresh upstream base | Fail | Fail | Fail | Fail | Fail |
| Existing fork | Pass | Pass | Fail | Fail | Fail |
| Prepared upstream fix | Pass | Pass | Pass | Pass | Pass |

MOS suites were run with `llvm-lit -v llvm/test/MC/MOS llvm/test/CodeGen/MOS` using
the fresh build's site configuration (container source/build mounts `/src`, `/build`).
Baseline including the new test: 129 passed, one failed (the new regression), one
unsupported. Patched: **130 passed, zero failed, one unsupported**; 47 MC passes
and 83 CodeGen passes. The unsupported test is disabled upstream.

Evidence: [baseline checks](mvn-baseline-components.txt),
[baseline suites](mvn-baseline-suites.txt), [fork checks](mvn-fork-components.txt),
[fixed checks](mvn-fixed-components.txt), [fixed suites](mvn-fixed-suites.txt).
Staged source/test comments passed the repository comment-history check before the
local preparation commit. The downstream source and patch were subsequently updated;
see [downstream validation](mvn-downstream-validation.md).

## BRL cost probe

Split [brl-cost.s](brl-cost.s) with `split-file`, assemble each part with
`llvm-mc -triple mos -mcpu=mosw65816 -filetype=obj`, then inspect with
`llvm-readobj --sections` and `llvm-objdump -d --mcpu=mosw65816`.
Fresh tools produce 132-byte `.text` for each: branch/jump three bytes, gap 128,
RTS one. BRA relaxes to `82 80 00`; JMP is `4c 00 00` with a relocation.
[Recorded output](brl-cost-results.txt). Cycle costs come from the datasheet cited
in the [assessment](brl-assessment.md), not from this byte-count probe.

## Common SDK longjmp zero

Current common assembly at SDK `3f6968bbc156ff9a63102a8e158db868819bd61c` was linked
explicitly into the installed 6502 simulator harness using local MOS clang,
`--config build/install/bin/mos-sim.cfg`, `-fno-lto`, and the
[reproducer](../../investigations/repro/upstream-issues-2026-09-20/longjmp-zero.c).
At each of `-O0`, `-O1`, `-O2`, `-Os`, values 0, 1, 7, 256 and -1 were tested.
Unmodified current assembly fails all four zero cases (exit 42); other cases pass.
The [candidate](sdk-longjmp-zero.patch) passes all 20 cases (exit 0).
[Matrix](sdk-longjmp-matrix.txt).

This isolates current upstream assembly using local supporting tools/libraries;
it is not a fresh build of the entire latest SDK. This earlier source-isolated check is supplemented by the completed
[integrated SDK CTest validation](sdk-longjmp-validation.md): fresh current SDK
libraries and simulator, 20/20 passes.
The downstream native SNES override also needs zero normalization; it was not
modified or freshly tested here. Its separate native-stack fix remains governed by
the platform/ABI contract described in the [report](../../upstream-sdk-setjmp-issue.md).
