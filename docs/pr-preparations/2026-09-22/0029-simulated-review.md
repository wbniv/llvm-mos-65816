# Patch 0029 — simulated upstream review

Local review of the proposed contribution; this is not maintainer feedback.
Scope: the standalone patch against llvm-mos
`742d554bf08042b8df93d791c335260fadd16643`, using stock `mos6502`.

- [x] Review the complete rescheduling function and register-overlap helper.
- [x] Check that the C reproducer reaches the failure without downstream features.
- [x] Review failing and legal MIR cases, including an intervening constrained operand.
- [x] Exercise both LiveVariables and LiveIntervals with the saved baseline and candidate.
- [x] Add the LiveIntervals invocation to the submitted regression and rerun both tests.
- [x] Link the published originating demo and state the validation scope.
- [x] Run focused X86, ARM, and AArch64 regressions with assertions enabled.

No blocking correctness finding was identified for the reported failure. The
C++ guard is unchanged by this review. One test-coverage improvement was applied:
the MIR regression now checks both available liveness-analysis paths.

## Correctness and scope

The move extends a physical definition from the argument copy across earlier
instructions. Those instructions can contain virtual operands that must occupy
the same physical register. The existing physical-operand dependency check
cannot see that allocation constraint.

The guard examines the current two-address instruction and every instruction
between it and the kill. It considers only live physical definitions, uses the
existing alias-aware overlap helper, and rejects a move when all members of a
crossed operand's register class overlap those definitions. The MIR tests check
the accumulator case, an intervening index-register constraint, and a legal
hoist into X while a GPR temporary retains alternatives.

This is a conservative class-overlap guard, not a complete register-pressure
analysis. It does not model every allocation restriction or interactions among
several simultaneously live virtual registers. The PR should not claim to
eliminate all possible register exhaustion. Full-register overlap can also reject
some moves where a narrower subregister use would be safe.

The check remains inside the pass's existing short rescheduling scan. `all_of`
stops at the first class member that does not overlap. A separate build now
passes 231 focused X86, ARM, and AArch64 regressions with assertions enabled.
Complete suites for those targets, other backends, and compile-time benchmarks
remain outside the available evidence.

## Regression evidence

| Analysis path | Baseline | Candidate |
| --- | --- | --- |
| LiveVariables | Required ordering fails | Ordering and verifier pass |
| LiveIntervals | Required ordering fails | Ordering and verifier pass |

The changed MIR test and full-codegen IR test both pass under llvm-lit after
adding the new invocation. Existing broader evidence remains 131 passing MOS
CodeGen/MC tests and one unsupported test. The isolated C-to-object matrix checks
all six optimization levels with and without MachineVerifier. Supplemental
simulator evidence is documented separately because it uses the local SDK.

The additional focused run passes 169 X86, 29 ARM, and 33 AArch64 tests with no
failures or skips, including all nine tests requiring assertions. Both bundled
MOS tests also pass in the new assertion-enabled build. No source or test changes
were needed. See the [cross-target validation record](0029-cross-target-validation.md)
for the exact selection and build scope.

The MIR examples are intentionally constructed to isolate the transformation;
the separate C/IR reproducer establishes ordinary frontend reachability on the
stock target. Neither requires `+mos-a16` or `+mos-xy16`.

## Review artifacts

- [Simulated PR page](0029-pr-preview.html)
- [Proposed PR description](../../upstream-twoaddr-physreg-reschedule-pr.md)
- [Exact patch](../../../patches/llvm-mos/0029-llvm-twoaddr-physreg-reschedule.patch)
- [Validation record](0029-validation.md)
- [Originating demo](https://biohack.net/snes/byvaledge/)

The patch is prepared locally and has not been submitted.
