# Patch 0037: independent review of analysis, implementation and submission

September 23, 2026. Reviewed Claude's [validation record](0037-validation.md),
[patch](../../../patches/llvm-mos/0037-llvm-gisel-inline-asm-indirect-output.patch),
[PR draft](../../upstream-gisel-inline-asm-indirect-output-pr.md), generic
GlobalISel lowering, SelectionDAG's corresponding path, and saved test evidence.
**Verdict: no implementation defect found.** The indirect outputs remain
register definitions for tied inputs, are excluded from direct-result accounting,
and are copied/truncated into typed values before stores through their pointers.
ABI alignment matches SelectionDAG's default store alignment. Multi-register
outputs remain unsupported; this patch does not fix the separate tied-operand
assertion.

## Submission and evidence corrections

1. The broad claim about every GlobalISel-only target exceeded the demonstrated
   scope. The draft now names the verified MOS and AArch64 cases. X86's missing
   inline-asm lowering does not validate this change.
2. The full cross-target run contained 11,436 PASS, 23 XFAIL and one failed
   AArch64 test. Matching the 785-test rerun by test name resolves that failure:
   the combined result is **11,437 PASS and 23 XFAIL**, total 11,460.
3. The suite and corpus records use a stacked compiler, not 0037 alone. The
   draft now distinguishes those historical results from the fresh isolated
   build below. The corpus retains 51 failures on both sides.
4. The destination is llvm/llvm-project, which has no MOS backend. Prepared
   [0037-llvm-project.patch](0037-llvm-project.patch) with exactly the same generic
   implementation and AArch64 test; the MOS test stays in the llvm-mos bundle.
   This is an extraction against the pinned llvm-mos base, not a claim of fresh
   applicability or CI against current llvm/llvm-project main.
5. Corrected the SelectionDAG reference: this pinned source uses `OutChains`
   and `DAG.getStore`, not an `IndirectStoresToEmit` identifier.

## Independent validation

Pinned base: `742d554bf08042b8df93d791c335260fadd16643`, assertions enabled,
with **0037 alone** in the isolated `asm-symbol-work` / `asm-symbol-build` tree.
No changes were made to Claude's active source/build tree.

| Check | Result |
|---|---|
| Exact bundled MOS/AArch64 RUN lines on before/after stacked binaries | All five fail before; all five pass after |
| Fresh 0037-only MOS CodeGen / MC / AArch64 GlobalISel suites | 84 / 46 / 785 pass, one unsupported, zero failures |
| Four C-torture sources × O0/O2/Os, pinned frontend, pristine vs 0037-only backend | Ten failures repaired; two already passing; all 12 pass with 0037 alone |
| Saved full corpus (`diff7`), all successful assembly files rehashed | Ten repaired, 4,109 identical successful pairs, 51 shared failures, zero hash mismatches |
| Fifteen additional AArch64 inputs × O0/O2 at IR translation, verifier enabled | All 30 pass |
| Full GlobalISel code generation of those inputs | 26 pass; four expose existing target limitations described below |
| Same 30 inputs through SelectionDAG | All pass |

The extra inputs cover i1/i8/i16/i32/i64, float/double, vectors, pointer values,
mixed direct/indirect outputs, two indirect outputs, early-clobber tied operands,
a non-default destination address space, strict alignment, and asm without the
`sideeffect` marker. The address-space-1 stores fail in AArch64 legalization;
`+strict-align` functions fail selecting the return. Corresponding plain IR
store/return controls fail on both pristine and patched GlobalISel, establishing
that these four full-codegen failures are existing limitations. Successful
translation is not claimed as complete support for those configurations.

Artifacts: `build/review-followups-0033-0037/0037-lit.json`, `0037-probes.json`,
`more-checks.json`, `run-tests.json`, `saved-evidence.json`, and generated probe
IR/MIR/assembly/logs. `llc-0037-only` freezes the isolated compiler, SHA-256
`0d745b76dad60e0169624de81d8d755b2e9cf46ef3411d673c11157a6fa9ebc3`.
The reviewed llvm-mos patch SHA-256 is
`fe3cd0653aa7648161f793ffb4e4523ebc82a41ef37b22b9bf7c5a1f019c09fd`.
No new emulator run or complete vanilla LLVM build is claimed.

Remaining submission work: check current llvm/llvm-project applicability and
validate the extracted submission there before posting. No source revision is
requested by this audit.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, standalone build and validation, evidence corrections,
submission-patch extraction, and documentation.
