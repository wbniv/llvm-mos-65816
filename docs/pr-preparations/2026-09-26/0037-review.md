# 0037: current-LLVM extraction follow-up

Date: 2026-09-26. Reviewer/extractor: OpenAI Codex CLI 0.157.1 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort; verified child session
`01a0db96-a6cd-7800-82a5-6b871eb7e177`.

Current disposition: the exact standalone LLVM package is approved and ready
to post, but unposted, after [the final receipt audit below](#final-llvm-main-validation).
The original extraction/replay assessment is retained as dated evidence.

## Initial verdict and remaining gate

Approve the current-source extraction for the coordinator's clean LLVM build.
No implementation defect or source API mismatch was found in this pass. This
does **not** certify current-LLVM code generation: the exact-main build and
matching-input baseline/candidate suite checks remain pending. Neither an
apply check nor historical compiler replay clears that gate. Nothing was
posted, pushed, or built by this follow-up.

The exact [submission patch](0037-llvm-project.patch), SHA-256
`c82dcc45750d99a0848634d18ce84df34ee90bf072f1c254e47ee1b3925c7d12`,
contains only `llvm/lib/CodeGen/GlobalISel/InlineAsmLowering.cpp` and
`llvm/test/CodeGen/AArch64/GlobalISel/inline-asm-indirect-output.ll`.
The [body](0037-pr-body.md) preserves dated validation boundaries and credits.

## Prior-work reconciliation and exact adaptation

Read the original [validation](../2026-09-23/0037-validation.md),
[independent review](../2026-09-23/0037-review-audit.md),
[generic artifact](../2026-09-23/0037-llvm-project.patch), and
[PR draft](../../upstream-gisel-inline-asm-indirect-output-pr.md).
Implementation entered repository history in `df7f68b9`; the previous generic
artifact has SHA-256
`5825112d2ed0b85be04c0a04ee7bb2a8c2463b216399397aa593fd5dfe810ccd`.
This is completion of its explicitly outstanding LLVM-main extraction gate,
not another discovery or a replacement compiler defect record.

Current base: LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`.
Its `InlineAsmLowering.cpp` SHA-256 is
`77a7c45827a3025b0fe83021d7846d837061d65f840e4412c28d1901eec3789c`.
The older artifact's output-accounting hunk removes a MOS-only explanatory
FIXME and expects additional MOS debug text, neither of which exists on LLVM
main. Adapted that context without importing either text or changing the
compiler algorithm. All other implementation additions remain unchanged.
Applied source SHA-256 in owned scratch is
`eb917dc82db07978ad8cd42c193347f919d5fbccff543a00377da0602537c450`.

The patch passes read-only `git apply --check` against the clean current LLVM
checkout. Application occurred only in
`build/post-ready-review-inline/0037/`, which contains a copied source file and
the new test, not a shared build or vendor tree. The current 0056 packet also
passes an apply check on top of this scratch source; it is not a prerequisite
for the two valid operands tested by 0037.

Source review confirms the existing contract: indirect outputs retain their
inline-asm register defs for tied operands, are excluded from the direct-result
count, and receive typed stores afterward. Current `getLLTForType`,
`MachineIRBuilder::buildTrunc`, and LLT-sized `getMachineMemOperand` APIs accept
the retained implementation. Alignment and destination pointer metadata are
unchanged from the previously reviewed SelectionDAG-matching contract.
Multi-register indirect outputs remain unsupported. No 0041 feature is imported;
the separate 0041 reviewer is extracting direct multi-register handling without
a semantic 0037 prerequisite. Neither change adds GlobalISel `callbr` support.

## Regression and replay

Kept the exact two-function AArch64 input and FileCheck patterns. Added O2
translation/full-codegen RUNs and `-verify-machineinstrs` to all four commands.
The test SHA-256 is
`5f60dac0dbf63a707a77e7764fe0598e00ba05891f87ba3be59c60116b4b34c9`.
This test uses only `llc`, `FileCheck`, and the standard `%s` substitution; no
tool or substitution is missing from the coordinator's current runner.

Read-only historical-snapshot replay:

| Snapshot | SHA-256 | Four RUN commands |
| --- | --- | --- |
| `build/0030-claude-review/llc-pristine-assert` | `21f45c5b1cf7dbd82841995d370ce8b7511cca226c9abd21ea07b3ec934c77b3` | All fail; each compiler reports `unable to translate instruction: call (in function: barrier)` |
| `build/review-followups-0033-0037/llc-0037-only` | `0d745b76dad60e0169624de81d8d755b2e9cf46ef3411d673c11157a6fa9ebc3` | All pass, including the MIR store/truncate checks and final assembly |

The original review identifies the latter as the assertion-enabled isolated
0037-only build on MOS pin `742d554`. This replay is not a clean LLVM-main
validation and does not reassert the old full-suite or runtime totals as new
results. Commands, input/tool hashes, and logs are under
`build/post-ready-review-inline/0037/replay-results.json`; the replay script is
`build/post-ready-review-inline/check0037.py`.

This pass independently inspected the earlier implementation. It authored the
new O2/verifier RUN lines, so it is not an independent review of those additions.
The coordinator's final exact-current receipt remains required before the
submission can be promoted to ready.

## Final LLVM-main validation

The coordinator's [exact-package receipt](validation/runs/post-ready-validation-llvm/0037/receipt.json),
SHA256 `27a5d66dbc4166a500f8f5ab0d173ea348ab22c1dfc864873bd88fb2c66420f8`,
records the unchanged patch and test hashes above, LLVM main
`e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`, and no prerequisite patch.
The build is Release with assertions enabled and X86/AArch64 targets, using
image `sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.

Pristine baseline `llc` SHA256:
`93b6a35c447f85042c65830e1daea85e0f6103c1fb380c3df78cec658009c81c`.
Candidate `llc` SHA256:
`1ec339ace0fdc82bdec427b081146bb723c80eb240b4fa881687afc736267132`.
The first baseline RUN fails with `unable to translate instruction: call (in
function: barrier)`; the runner stops that baseline file after the failure.
All four candidate O0/O2 translation/full-codegen RUNs pass, including store,
truncation, assembly and MachineVerifier checks with fallback disabled.
The current receipt does not claim that all four baseline RUNs were rerun;
the separate historical replay above did exercise those four commands.

Filtered AArch64/X86 inline-asm suites report baseline 167 passes and three
expected failures; candidate 168 passes and the same three expected failures,
with zero unexpected failures. The selection is
`(inline.?asm|asm-goto|callbr)`, excluding 9,786 other tests; these are not full
AArch64/X86 suites or a new runtime result.

Independent final audit matched the patch, both input snapshots, all nine
referenced logs in local and archived copies, archived runner, configuration,
and both phases' `llc`, `FileCheck`, `not`, and `split-file` hashes. Exact test
bytes reconstructed from the packet match the snapshots. The coordinator's
clean build/test execution is OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort, session
`01a0db16-f6a0-7e32-ada6-0c8098813933`; this final receipt audit uses the reviewer
identity at the top and performed no build or test rerun. The earlier authorship
qualification for my O2/verifier test additions remains.

**The exact 0037 package is approved and ready to post, unposted.** Its current
LLVM build/test gate is complete; no 0041 or 0056 prerequisite is introduced.
