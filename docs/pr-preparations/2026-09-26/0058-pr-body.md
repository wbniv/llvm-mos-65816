# [AArch64] Reject unknown inline-asm integer types before querying their size

The AArch64 `r` and `x` register-constraint handlers query the bit size of an unknown `MVT::Other` type. For nonstandard-width integer inline-asm operands, that query aborts rather than rejecting the unsupported constraint.

Return no register class for `MVT::Other` before making the size query, matching the existing unknown-type handling in the `w` case. Known integer types, named clobbers, and supported scalar/vector cases keep their current behavior. This does not add support for arbitrary-width integer register operands.

The regression covers i4096 inputs and outputs through `r` and `x`, i65 tied and indirect operands, `callbr` recovery, and supported controls at O0/O2. The **full regression stack requires 0057's SelectionDAG recovery**. That prerequisite must be stated in the eventual PR relationship; the target guards are not evidence that `callbr` recovery is independently fixed here.

Original matching-input evidence includes a separately preserved 0057 compiler that still reproduces the type abort. Independent review confirms the two guards and the dependency. Fresh validation of this exact submission artifact against the pinned LLVM main is complete, as recorded below. This draft is unposted.

Fresh isolated validation on LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5` (Release, assertions enabled): all 19 focused RUN commands pass. The relevant AArch64/X86 inline-assembly/callbr suite has 169 passes, three pre-existing expected failures, and no unexpected failures. The baseline includes only prerequisite 0057; adding this candidate clears its distinct recorded failure. Exact patch, input, binary hashes, and logs are retained in the local packet.

Earlier implementation and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, as recorded in the canonical record. Submission preparation: the same recorded tool/model/effort, verified parent session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent review: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db96-a6cd-7800-82a5-6b871eb7e177`.
