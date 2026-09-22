# Patch 0029: focused X86, ARM, and AArch64 validation

This run checks existing regressions near the shared two-address pass, register
allocation, and copy coalescing. It uses llvm-mos
`742d554bf08042b8df93d791c335260fadd16643` with only
[patch 0029](../../../patches/llvm-mos/0029-llvm-twoaddr-physreg-reschedule.patch)
applied. The patch SHA-256 is
`1b0aee741ed2a9e8b7a1d433e5ae314d19613c581992111ed50be2feca8b4905`.

> **Superseded:** the patch was refined after this run (reserved class members
> are no longer counted as available). The revised hash is
> `c2c962311fc40a43d570f141ef0ba6240b317952456bea17c56c1f90066ced88` and the
> complete X86, ARM, AArch64 and MOS suites for it are recorded in the
> [independent review](0029-claude-review.md). The selection results below are
> for the earlier hash.

- [x] Select existing tests and save their paths and source hashes.
- [x] Build the patched compiler with assertions enabled.
- [x] Run the selected regressions and investigate any failures.
- [x] Update the proposed PR description and simulated review.

## Results

| Target | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| X86 | 169 | 0 | 0 |
| ARM | 29 | 0 | 0 |
| AArch64 | 33 | 0 | 0 |
| Total | 231 | 0 | 0 |

All nine tests requiring assertions ran and passed. The two bundled MOS
regressions also passed in this assertion-enabled build: `mixed-width-call.ll`
and `twoaddr-reschedule-physreg.mir`. The compiler reports an optimized build
with assertions and registers all four requested backends.

No compiler or test changes were needed. The patch hash and all selected test
hashes were verified after execution. The proposed PR description and
[simulated review](0029-simulated-review.md) include these results.

## Selection and scope

Select `.ll` and `.mir` files below `llvm/test/CodeGen/{X86,ARM,AArch64}`,
excluding `Inputs` directories, if either condition holds:

- The filename matches `two.?addr|coalesc|regalloc|reg.alloc|register.alloc|phys.?reg|tied|commut`, case-insensitively.
- The file contains `twoaddressinstruction|twoaddr-reschedule|rescheduleKillAboveMI`.

This selects 231 test files: 169 X86, 29 ARM, and 33 AArch64. Nine explicitly
require an assertion-enabled compiler. Tests run with their checked-in commands;
MachineVerifier is enabled where those commands request it. Both legacy and new
pass-manager invocations occur in the selection.

This is a focused regression run, not the complete CodeGen suites or a
compile-time benchmark. Generated X86/ARM/AArch64 programs are not executed.

### Backend coverage at the pinned revision

| Coverage for patch 0029 | Backends |
| --- | --- |
| CodeGen and MC suites: 131 pass, one unsupported; both bundled tests also pass with assertions | MOS |
| Focused CodeGen selection: 231 pass with assertions, no skips | X86, ARM, AArch64 |
| Not tested: 18 other standard backends | AMDGPU, AVR, BPF, DirectX, Hexagon, Lanai, LoongArch, Mips, MSP430, NVPTX, PowerPC, RISCV, Sparc, SPIRV, SystemZ, VE, WebAssembly, XCore |
| Not tested: four other experimental backends | ARC, CSKY, M68k, Xtensa |

The remaining-backend inventory comes from `LLVM_ALL_TARGETS` and
`LLVM_ALL_EXPERIMENTAL_TARGETS` in the pinned source's `llvm/CMakeLists.txt`,
cross-checked against `llvm/lib/Target` directories. MOS is an additional backend
in this llvm-mos source. Thus 22 backends remain untested for this patch; the
complete X86, ARM, and AArch64 suites also remain unrun. These results apply to
0029 and do not extend patch 0028's separate validation.

## Build

The isolated source and build directories are `build/register-exhaustion-src` and
`build/0029-cross-target-build`. This reuses the isolated patched source with a
new build directory; the saved MOS-only compiler and unpatched reference remain
intact. All three patch files match a fresh application to pristine upstream.
Two untracked tests from the separate 0028 work exist in this source directory
and are outside the selection. Commands below run in the
`llvm-mos-65816-dev` container with this repository mounted at `/work` and the
working directory set to `/work`.

```sh
cmake -G Ninja \
  -S build/register-exhaustion-src/llvm \
  -B build/0029-cross-target-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DLLVM_USE_LINKER=lld \
  '-DLLVM_TARGETS_TO_BUILD=X86;ARM;AArch64' \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=MOS \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_INCLUDE_TESTS=ON \
  -DLLVM_BUILD_UTILS=ON \
  -DLLVM_ENABLE_PROJECTS= \
  -DLLVM_ENABLE_RUNTIMES= \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_PARALLEL_TABLEGEN_JOBS=2

cmake --build build/0029-cross-target-build --parallel 6 \
  --target llc opt FileCheck not count llvm-config
```

The initial test setup required two adjustments: lit's mandatory `count` helper
and feature-query tool `llvm-config` were built, and the runner uses a 600-second
overall timeout per invocation because the container lacks the `psutil` module
needed for lit's per-test timeout. These were harness setup issues before any
tests ran. The final run reports no failures or unsupported tests. Notes about
other unbuilt LLVM tools concern tools not used by this selection.

## Evidence

Local artifacts are in `build/0029-cross-target/`:

- `manifest.json`: upstream revision, patch hash, selection rule, and build scope.
- `selected-tests.json`: selected paths, inclusion reasons, test directives,
  and SHA-256 hashes; `selected-tests.txt` is the corresponding path list.
- `configure.log`, `cmake-settings.json`, `build.log`: compiler configuration,
  relevant CMake settings, and build output.
- `build-helpers.log`, `llc-version.txt`: helper-tool build and compiler identity.
- `run-tests.py`, `test-command.json`: test runner and exact llvm-lit invocation.
- `lit.log`, `lit-results.json`: test output and machine-readable results.
- `mos-test-command.json`, `mos-lit.log`, `mos-lit-results.json`: the two bundled
  MOS regressions in the same assertion-enabled configuration.
- `summary.json`: per-target totals and post-run integrity checks.

The runner invokes the build's `bin/llvm-lit -v -j 6` with every
selected path under the build's `test` directory and writes JSON results using
`--output`. The focused run completed in 2.00 seconds; the separate two-test MOS
run completed in 0.35 seconds. These are test-run durations, not compile-time
benchmark results.
