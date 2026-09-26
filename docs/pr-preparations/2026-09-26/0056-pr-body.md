# [GlobalISel] Diagnose an insufficient physical-register inline-asm range

An inline-asm operand can require multiple registers while naming a physical
register at the end of its class. The allocation loop walks the class iterator
past its end; assertion-enabled builds abort instead of reporting an invalid
constraint. The same loop also advances that iterator for virtual-register
allocation, although virtual registers have no class-member-count limit.

Separate the two cases. Allocate virtual registers without walking physical
members. For a physical constraint, locate the named member without dereferencing
the end iterator and validate the complete required range before assigning any
operand registers. Preserve upstream's register-class selection and existing
register-count calculation.

When the physical range is insufficient, issue an inline-asm error and omit the
invalid assembly. A returning diagnostic handler still needs defined output
vregs, so provide undef results before returning from translation. This recovery
does not turn the compilation into success or fall back to another selector.

The AArch64 regression requests an i128 value from the single-register NZCV
class. It covers direct output, input, tied input/output, and indirect output,
with live results, at O0/O2 and both GlobalISel fallback settings. The tests do
not depend on the separate indirect-output or valid multi-register feature
patches; every invalid range is rejected before those operand paths.

The canonical defect evidence
retains the exact original red/green pair. The September 26 submission variant
targets LLVM main and intentionally does not import the downstream
`getNumRegistersForInlineAsm` extension. Nothing here adds inline `callbr`
support to GlobalISel. This draft is unposted.

Fresh isolated validation on LLVM `e59a0c697552ae7d1c3aeed5774e829cdc5e16b5`
(Release, assertions enabled): all 4 focused RUN commands pass. The relevant
AArch64/X86 inline-assembly/callbr suite has 168 passes, three pre-existing
expected failures, and no unexpected failures. The pristine baseline
reproduces the recorded register-range assertion on the same input.
Exact patch, input, binary hashes, and logs are retained in the local packet.

Earlier implementation and validation: OpenAI Codex CLI 0.157.0 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort, as recorded in the canonical record.
Submission preparation: the same recorded tool/model/effort, verified parent
session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent review: OpenAI
Codex CLI 0.157.1, model `gpt-6-astra`, `xhigh` reasoning effort; verified
reviewer session `01a0db96-a6cd-7800-82a5-6b871eb7e177`.
