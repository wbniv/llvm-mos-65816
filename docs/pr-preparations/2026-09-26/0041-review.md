# 0041: final LLVM source and validation audit

Date: 2026-09-26. Reviewer: OpenAI Codex CLI 0.157.1 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db96-a6cd-7800-82a5-6b871eb7e177`, agent `/root/review_inline_asm`.
This is a separate same-model source/evidence review, not human review.
The earlier [extraction review](0040-0041-review.md) and its authorship remain
intact. This audit changed no compiler source and ran no compiler build or test.

## Final artifact and source disposition

Approve the final [standalone LLVM patch](0041-llvm-project.patch), SHA256
`8819a60f6f7a51bfbc0a17609babc8c64db137e09ed28b8fa0f92f6a04014b7c`.
Its only difference from the earlier reviewed
`2b8e1087e94ba26b53ec3ff95a45f8f7a04873a955f838ce85f9ffc68dbaab7a`
is three test-comment lines limiting the register-class explanation to the
tested `i128` `r` operands. Replacing those three lines in memory reconstructs
the earlier SHA256 exactly. No source, RUN command, IR or FileCheck changed.
The new AArch64 test now hashes to
`662d14df41fa54f701f56d43c263771c488bdebabf5728cfee4b94d6347bd3f0`;
the earlier `17f9b081...` test hash remains historical evidence, not final bytes.

Independent source inspection confirms that output `G_ANYEXT` occurs only
after merging multiple register pieces into a typed scalar, and only when the
scalar result is wider. Single-register output rejection is unchanged. This
matches pinned LLVM SelectionDAG's integer `ISD::ANY_EXTEND` contract, rather
than depending on historical MOS's zero-extension branch. All three output
forms explicitly check `G_MERGE_VALUES` followed by `G_ANYEXT` at O0/O2.
`build-pair-isel.ll` retains its existing assembly checks under explicit
SelectionDAG and separately checks GlobalISel codegen with fallback disabled.
The packet does not include or require 0037, 0056, or MOS register-count APIs.
The earlier unsupported-shape qualifications remain; this is not universal
assertion-free malformed-asm support.

## Exact-current evidence

The coordinator's [archived receipt](validation/runs/post-ready-validation-llvm/0041/receipt.json)
has SHA256 `9dae5e95608489a101ae319d50981ff37cce76df27e95cee7cb8855f8d98c4b8`.
It records LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`, no prerequisite,
Release with assertions enabled, X86/AArch64 targets, and image
`sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1`.
Baseline `llc` SHA256 is
`93b6a35c447f85042c65830e1daea85e0f6103c1fb380c3df78cec658009c81c`;
candidate `llc` SHA256 is
`d535b1b535f88a0a8a5b771f2a3ff166991c442239da951ae18e7e0acbbf1e4c`.

The baseline fails the new regression at
`InlineAsmLowering.cpp:409`'s `getNumOpRegs(...) == 1` / `Wrong flag` assertion.
Its explicit GlobalISel `build-pair-isel.ll` run separately fails to translate
the call in `compare_and_swap128`. The retained SelectionDAG check and the four
remaining fallback-test RUNs pass on the baseline. The runner stops each file
after its first failure; it does not establish every new regression RUN red.

All ten candidate focused RUNs pass: four fallback checks, four new O0/O2
translation/codegen commands, and two selector-specific build-pair commands.
Filtered AArch64/X86 inline-asm suites report baseline 167 passes plus three
expected failures and candidate 168 passes plus the same three expected
failures, with zero unexpected failures. The filter
`(inline.?asm|asm-goto|callbr)` excludes 9,786 other tests; full target suites,
runtime and upstream CI are not claimed. The build-pair test is outside that
filter but is explicitly covered by its two focused commands.

I reconstructed all three changed test files from the exact patch and pinned
LLVM originals. They match both phases' six input snapshots byte for byte.
All 21 referenced logs match local and archived copies, as do receipt, runner,
configuration, and the eight `llc`, `FileCheck`, `not`, and `split-file`
snapshot hashes. The read-only checker is
`build/post-ready-review-inline/audit-llvm-final.py`.

Build/test execution credit: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; coordinator session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. Extraction credits remain in the earlier
review and PR body; final independent review is attributed above.

**The exact 0041 package is approved and ready to post, unposted.** No remaining
source/build/test blocker was found. Nothing in this audit authorizes posting
or changes the unrelated historical #320/#321 hold.
