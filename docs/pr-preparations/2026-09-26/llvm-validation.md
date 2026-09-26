# LLVM posting packets: exact-current validation

The destination base is LLVM main
`e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`. A separate clean
Release/assertions-enabled X86+AArch64 build validates seven exact packets.
Six are ready to open; 0028 retains the user's #320/#321 presentation hold.

| Package | Baseline prerequisite | Focused RUNs | Candidate suite result |
|---|---|---:|---|
| [0028](validation/runs/post-ready-validation-llvm/0028/receipt.json) | None; presentation hold remains | 2 | 102 passes / one existing XFAIL |
| [0037](validation/runs/post-ready-validation-llvm/0037/receipt.json) | None | 4 | 168 passes / three existing XFAILs |
| [0041](validation/runs/post-ready-validation-llvm/0041/receipt.json) | None for the direct-operand submission | 10 | 168 passes / three existing XFAILs |
| [0056](validation/runs/post-ready-validation-llvm/0056/receipt.json) | None; retains upstream register-count API | 4 | 168 passes / three existing XFAILs |
| [0057](validation/runs/post-ready-validation-llvm/0057/receipt.json) | None | 2 | 168 passes / three existing XFAILs |
| [0058](validation/runs/post-ready-validation-llvm/0058/receipt.json) | 0057 for full callbr regression | 19 | 169 passes / three existing XFAILs |
| [0059](validation/runs/post-ready-validation-llvm/0059/receipt.json) | 0057 for full vector regression | 24 | 169 passes / three existing XFAILs |

All candidates have zero unexpected failures and the expected matching-input
baseline failure. These are **filtered** AArch64/X86 suites, not full target
suites: inline-assembly/callbr for 0037/0041/0056–0059; register-allocation,
spill, and undef-subregister tests for 0028. Baseline suite counts are 167/3
for the standalone inline-assembly packets, 168/3 when 0057 is applied first,
and 100/1 for 0028. Exact filters, commands, logs, inputs, compiler hashes,
patch/dependency hashes, configuration, and executed runner copies are in the
linked immutable receipts and adjacent files.

The build runs without network access in image
`sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.
Its [captured container identity](validation/llvm-build-container.json) belongs
to this build; reviewer containers have separate identities. Source and build
directories are `build/post-ready-2026-09-26-llvm-src` and
`build/post-ready-2026-09-26-llvm-build`. The
[pristine build log](validation/llvm-pristine-build.log) is retained.

## 0060: existing upstream fix, not a new LLVM submission

Current LLVM already rejects parallel MIR at the CLI, from
[upstream commit b1ba3d515a02](https://github.com/llvm/llvm-project/commit/b1ba3d515a0238adbfc6c349ed3b33f9060cea72)
(September 24), before our September 25 local report. The old
`0060-llvm-project.patch` serial fallback is a **rejected preparation attempt**,
not a posting candidate. Its [failed run](validation/runs/post-ready-validation-llvm/0060/receipt.json)
is retained: the standalone runner also failed to resolve a bare FileCheck
argument, while lit exposed the pre-existing CLI rejection. Neither failure is
red/green evidence for a new LLVM defect. Follow-up tests use an absolute
FileCheck path and valid MIR, confirming current LLVM's serial-success /
parallel-rejection policy.

The applicable packet is the [MOS guard backport](0060-pr-body.md), tracked in
[the MOS validation summary](mos-validation.md). The carried parallel candidate
and original baseline remain dated evidence; general parallel-MIR context
isolation is not established. No duplicate LLVM bug or parallel-support claim
is prepared.

Coordination and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent reviewers are credited in
their own records. Nothing has been posted or pushed.
