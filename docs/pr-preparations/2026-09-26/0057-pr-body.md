# [SelectionDAG] Check physical-register ranges for inline assembly

SelectionDAG's inline-asm register allocator currently checks whether a named register belongs to a class, but not whether enough members remain to hold the operand. A wide operand at the end of the class can overrun the iterator. The same iterator is unnecessarily bounded when allocating virtual registers.

Allocate virtual registers without iterating through physical class members. For a physical constraint, check both membership and the complete required range before filling the operand's register list. Reject an insufficient range through the existing register/type diagnostic route.

A diagnostic handler may return and allow lowering to continue. In that case, an invalid inline `callbr` has no output-copy chain for its indirect edge. Define the landing-pad result as undef when the compilation already carries an error, instead of trying to follow that absent chain. This is error recovery only; normal successful `callbr` lowering is unchanged.

The AArch64 regression covers direct, indirect, input, tied, and `callbr` operands, including live scalar and aggregate results on both direct and indirect edges. The input asks the one-member NZCV class to hold i128. Both O0 and O2 must emit the expected diagnostics without an assertion or MachineVerifier failure.

This is an independent generic LLVM submission. The full 0058 and 0059 regression packages build on its recovery/allocation behavior; they may be opened as an explicit stack, without claiming that their prerequisites have merged. Preserved matching-input evidence and independent review remain separate from the fresh submission-build record. This draft is unposted.

Fresh isolated validation on LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5` (Release, assertions enabled): all 2 focused RUN commands pass. The relevant AArch64/X86 inline-assembly/callbr suite has 168 passes, three pre-existing expected failures, and no unexpected failures. The pristine baseline reproduces the recorded register-range assertion on the same input. Exact patch, input, binary hashes, and logs are retained in the local packet.

Earlier implementation and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, as recorded in the canonical record. Submission preparation: the same recorded tool/model/effort, verified parent session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent review: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db96-a6cd-7800-82a5-6b871eb7e177`.
