# Register-exhaustion fix: local validation

Patch: [0029-llvm-twoaddr-physreg-reschedule.patch](../../../patches/llvm-mos/0029-llvm-twoaddr-physreg-reschedule.patch).
Submission text: [PR draft](../../upstream-twoaddr-physreg-reschedule-pr.md).
Review: [simulated PR page](0029-pr-preview.html) and
[review notes](0029-simulated-review.md).
The submission and both bundled tests use plain `mos6502`.

## Diagnosis

The saved upstream Clang reproduces the failure from the
[C input](../../investigations/repro/upstream-issues-2026-09-22/mixed-width-call.c).
The first invalid allocation constraint appears in the two-address pass, before
coalescing or machine scheduling: the pass hoists the first argument's physical
`$a` copy above `EORIndirIdx`, extending `$a`'s fixed live range across `Ac`
operands. Disabling `-twoaddr-reschedule` makes the same IR compile with
MachineVerifier. Disabling machine scheduling alone does not fix it.

The implementation adds a register-class availability check to
`rescheduleKillAboveMI`. It rejects a move if all registers in any crossed
virtual operand's class alias the moved instruction's live physical definitions.
This addresses the actual constraint without changing the source program,
allocator, register classes, or optimization-level defaults.

## Isolated upstream build

- Baseline: `742d554bf08042b8df93d791c335260fadd16643`.
- Saved reference: `build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/`.
- Candidate source/build: `build/register-exhaustion-src` and
  `build/register-exhaustion-build`.
- Release, assertions disabled, MOS target; verifier enabled explicitly in the
  checks that claim it. No other source patch is applied to this candidate.
- Build container: `llvm-mos-65816-dev`, the saved reference's existing image.

The candidate build uses copies of the source and incremental build, mounted at
their configured paths `/work/build/upstream-src` and `/work/build/upstream-llc`.
The saved compiler and baseline source remain unchanged.

| Check | Result |
|---|---|
| C to object, plain 6502, six optimization levels, normal and verifier | Patched 12/12 pass; baseline only the two `-O0` legs pass |
| Same matrix for existing upstream `mosw65816` | Same results |
| Bundled MIR ordering checks against baseline | Fail as expected |
| MIR with LiveIntervals instead of LiveVariables | Baseline ordering checks fail; patched checks and verifier pass |
| Bundled full-codegen IR test against baseline | Register-exhaustion error |
| MOS CodeGen and MC suites | 131 pass, one unsupported |
| Focused X86 / ARM / AArch64 regressions, assertions enabled | 169 / 29 / 33 pass; no failures or skips |
| Both bundled MOS regressions, assertions enabled | 2/2 pass |
| Patch applies to pristine upstream and the downstream vendor tree | Pass |
| Patch comments and source whitespace | Pass |

Suite invocation inside the container with the candidate mounts:

```sh
build/upstream-llc/bin/llvm-lit -v \
  --filter-out='virtregrewriter-(copy-liveness|undef-lane-identity-copy)' \
  build/upstream-llc/test/CodeGen/MOS build/upstream-llc/test/MC/MOS
```

The two excluded files are untracked local tests from the separate 0028 work;
neither belongs to the pinned upstream suite or this patch. The first broad run
also found a missing `llvm-readelf` tool alias; creating the alias to the existing
`llvm-readobj` resolved the MC test setup failure. The final run has no failures.

The simulated review added a second MIR pass invocation using LiveIntervals.
Both analysis paths now have the same three ordering checks. This changes only
test coverage; the C++ implementation is unchanged. See
`build/register-exhaustion/review.json` and `review.*.liveintervals.*` for the
baseline/candidate comparison.

## Focused X86, ARM, and AArch64 validation

A separate Release build with assertions enabled passes all 231 selected
two-address, allocation, coalescing, physical-register, tied-operand, and
commutation regressions: 169 X86, 29 ARM, and 33 AArch64. There are no failures or
skips; all nine tests requiring assertions ran and passed. The two bundled MOS
tests also pass in this configuration. No patch changes were needed.

The selection, build commands, scope, and result artifacts are documented in the
[cross-target validation record](0029-cross-target-validation.md). Coverage for
these three targets is limited to the focused selection; their complete CodeGen
suites, generated-program execution, other backends, and compile-time benchmarks
remain outside this validation.

## Runtime check

The patched upstream Clang emits the reproducer into a native MOS object,
separately from its caller and the definition of `ext`. A deterministic Python
oracle supplies 256 inputs and all three expected output words: boundary values
and seeded random values, including the untouched neighboring byte. The external
function computes `(a ^ 0x5a5a) + b + (a << 3)`, truncated to 16 bits.

Host execution and the SDK's 6502 `mos-sim` both pass all cases. The simulator
passes separately for `-O0`, `-O1`, `-O2`, `-O3`, `-Os`, and `-Oz`: 1,536 target
cases. MachineVerifier is enabled while emitting the target objects.

This runtime harness uses the local SDK and downstream linker to process that
SDK's existing bitcode libraries, whose data layout includes downstream address
spaces. The tested `stage` object is emitted by the isolated upstream-plus-0029
compiler and is not LTO bitcode. An initial link with the upstream linker rejected
the SDK data layout. These runtime checks are supplemental local evidence;
the upstream PR's validation claims rely on the isolated compilation and lit tests.

## Downstream integration

`dev/toolchain.sh` applies 0029 as a standalone generic LLVM patch. It does not
belong in the MOS-directory mirror used to regenerate 0002. The live vendor
source contains the patch, and local Clang/LLD were rebuilt and installed.

The downstream C reproducer passes 24/24 verifier-enabled compilations: six
optimization levels across plain 6502, ordinary 65816, and the two local native
width modes. Both new tests and the existing `commute.mir` pass in the downstream
build. These local feature checks are not part of the upstream submission.

## Evidence files

Local build artifacts are under `build/register-exhaustion/`:

- `coalescer.log`, `greedy.log`, `pre-twoaddr.mir`, `no-reschedule.s`:
  pass-level diagnosis.
- `build.log`, `lit-final.log`, `matrix.json`: isolated candidate results.
- `validate.py`, `runtime.c`, `runtime.*.log`: oracle generator, harness,
  and runtime results.
- `downstream.py`, `downstream-matrix.json`, `downstream-lit.log`,
  `downstream-build.log`, `install.log`: downstream checks and installation.

The fix has not been submitted as an upstream PR.
