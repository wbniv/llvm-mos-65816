# Patch 0029 — simulated upstream review

Local AI-assisted review of the proposed contribution; this is not maintainer feedback.
Scope: the standalone patch against llvm-mos
`742d554bf08042b8df93d791c335260fadd16643`, using stock `mos6502`.

- [x] Review the complete rescheduling function and register-overlap helper.
- [x] Check that the C reproducer reaches the failure on `mos6502`.
- [x] Review failing and legal MIR cases, including an intervening constrained operand.
- [x] Exercise both LiveVariables and LiveIntervals with the saved baseline and candidate.
- [x] Add the LiveIntervals invocation to the submitted regression and rerun both tests.
- [x] State the validation scope.
- [x] Run focused X86, ARM, and AArch64 regressions with assertions enabled.
- [x] Review the final patch, regression assertions, and proposed PR description.

No blocking correctness finding was identified for the reported failure. The
C++ guard is unchanged by this review. One test-coverage improvement was applied:
the MIR regression now checks both available liveness-analysis paths.

## Final submission review — September 22

No actionable defect was found in the final submission bundle. No additional
source or regression changes were needed. The reviewed patch SHA-256 is
`1b0aee741ed2a9e8b7a1d433e5ae314d19613c581992111ed50be2feca8b4905`.

> **Superseded on 2026‑09‑22 by the [independent review](0029-claude-review.md).**
> That review kept the predicate but refined the guard so reserved class
> members no longer count as available, and reworded its comment. The revised
> patch is `c2c962311fc40a43d570f141ef0ba6240b317952456bea17c56c1f90066ced88`;
> its full-suite validation is recorded there. The results below describe the
> earlier hash.
The patch and all three resulting files match the cross-target validation
manifest. The recorded results contain 231 passing cross-target tests and two
passing bundled MOS tests; the PR description accurately limits those claims.

The source review checked the complete move legality scan, its callers, and
register-class access. This pass runs after instruction selection, where virtual
registers have register classes. The scan skips debug instructions and pseudo
probes, rather than target pseudo instructions generally. The guard covers both
virtual uses and definitions, includes intervening instructions, ignores dead
physical definitions, and uses the existing alias-aware overlap helper.

A fresh check ran each MIR case separately with the saved unpatched compiler,
the assertion-enabled candidate, and the candidate with rescheduling disabled.
The following results hold for both LiveVariables and LiveIntervals:

| Ordering check | Unpatched | Candidate | Rescheduling disabled |
| --- | --- | --- | --- |
| Accumulator argument remains after arithmetic | Expected failure | Pass | Pass |
| Legal X argument hoists before arithmetic | Pass | Pass | Expected failure |
| Y argument remains after the intervening indexed store | Expected failure | Pass | Pass |

All six compiler invocations passed MachineVerifier. All 18 individual ordering
checks produced the expected result. In particular, the legal-X check rejects
disabling the optimization wholesale. This supplements the earlier full-codegen
and cross-target runs; those unchanged suites were not rerun for this review.
Commands, MIR output, FileCheck diagnostics, and hash verification are saved in
`build/0029-final-review/`, with the summary in `results.json`.

The remaining submission work is to check applicability against current
upstream, prepare the standalone branch, and publish the PR. This review used
the pinned revision above and did not contact maintainers or submit a PR.

## AI attribution

Checked the [AI tool policy in llvm-mos's current tree](https://github.com/llvm-mos/llvm-mos/blob/main/llvm/docs/AIToolPolicy.md)
on September 22. It expects disclosure of substantial tool-generated content in
the PR description or commit message and gives `Assisted-by` as an example.
The PR draft and preview now attribute OpenAI Codex's assistance with diagnosis,
implementation, tests, validation, and PR drafting.
The session metadata records Codex CLI `0.155.1`, model `gpt-6-astra`, and
reasoning effort `xhigh`; the attribution includes these exact values.

The policy also requires the contributor to read and review generated code and
text before requesting project review. The automated review recorded here does
not establish that human review has been completed.

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
all six optimization levels with and without MachineVerifier.

The additional focused run passes 169 X86, 29 ARM, and 33 AArch64 tests with no
failures or skips, including all nine tests requiring assertions. Both bundled
MOS tests also pass in the new assertion-enabled build. No source or test changes
were needed. See the [cross-target validation record](0029-cross-target-validation.md)
for the exact selection and build scope.

The MIR examples are intentionally constructed to isolate the transformation;
the separate C/IR reproducer establishes ordinary frontend reachability on the
`mos6502`.

## Review artifacts

- [Simulated PR page](0029-pr-preview.html)
- [Proposed PR description](../../upstream-twoaddr-physreg-reschedule-pr.md)
- [Exact patch](../../../patches/llvm-mos/0029-llvm-twoaddr-physreg-reschedule.patch)
- [Validation record](0029-validation.md)
- [Independent review and full-suite validation](0029-claude-review.md)

The patch is prepared locally and has not been submitted.
