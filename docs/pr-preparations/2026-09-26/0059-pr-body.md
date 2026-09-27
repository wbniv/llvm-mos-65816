# [SelectionDAG] Diagnose incompatible vector parts in inline assembly

Generic inline-asm lowering can receive a vector whose requested register parts do not match the target's vector breakdown. The split/join paths assert on that mismatch; a related vector-to-scalar path can attempt a lossy conversion without a suitable diagnostic.

After giving target-specific lowering hooks their existing opportunity, validate the generic part count and type. Diagnose incompatible parts and unsupported lossy conversion rather than asserting. Error recovery supplies the requested vector undef when joining and initializes every requested part when splitting. Supported equal-width bitcasts and target-provided conversions remain available. Use the call-site abstraction that includes `callbr` when attaching the diagnostic.

The AArch64 regression includes the retained 64-lane case, both operand directions, tied/indirect forms, and `callbr`, together with supported scalarized, floating-point, small-vector, and LS64 controls. It runs at O0/O2. The **full package requires 0057** for unbounded virtual-register allocation and error recovery; this is a semantic/test prerequisite, not an apply-order conflict.

Preserved evidence shows that the identical original input still fails after 0057 and after 0058, then receives the intended diagnostic with this change. That baseline remains immutable. Independent review covers the algorithm, positive cases, and recovery. This draft is unposted.

Fresh isolated validation on LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5` (Release, assertions enabled): all 24 focused RUN commands pass. The relevant AArch64/X86 inline-assembly/callbr suite has 169 passes, three pre-existing expected failures, and no unexpected failures. The baseline includes only prerequisite 0057; adding this candidate clears its distinct recorded failure. Exact patch, input, binary hashes, and logs are retained in the local packet.

Earlier implementation and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, as recorded in the canonical record. Submission preparation: the same recorded tool/model/effort, verified parent session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent review: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db96-a6cd-7800-82a5-6b871eb7e177`.
