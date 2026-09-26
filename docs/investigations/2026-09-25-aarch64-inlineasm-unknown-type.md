# AArch64 inline-assembly unknown operand types

Patch [0058](../../patches/llvm-mos/0058-aarch64-inline-asm-unknown-type.patch)
repairs the [nonstandard integer type abort](../defects/selectiondag-inline-asm-nonstandard-integer.json).
The original `i4096` input now receives a normal register-allocation diagnostic.
The separate [vector part-type assertion](../defects/selectiondag-inline-asm-vector-parts.json)
was left open by 0058. **Follow-up:** [0059](2026-09-25-selectiondag-vector-parts.md)
repairs its generic conversion diagnostics with matching-input red/green evidence;
the original failing baseline is retained.

Diagnosis, implementation, regression coverage, and documentation: OpenAI Codex
CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort,
verified from this turn's [session metadata](../defects/evidence/2026-09-25-aarch64-asm-type/session-identity.json).

## Failure and repair

SelectionDAG's constraint parser represents operand types without a simple MVT
as `MVT::Other`. AArch64's `r` and `x` handlers query the type's size to choose
a register class. That query has no meaning for `Other` and aborts. The existing
`w` handler already rejects this case. Both affected handlers now reject unknown
types before asking for their size, allowing the existing inline-asm diagnostic
and recovery paths to handle the unsupported constraint/type combination.

This does not add support for arbitrary-width integer register operands. Memory
operands can still carry those values; named clobbers still work without a value
type. Supported general-purpose, SIMD, and LS64 register operands retain their
existing lowering. The two-line target change leaves generic vector-part lowering
untouched.

## Baseline and causality

The [original LLVM IR](../defects/evidence/2026-09-25-selectiondag-inlineasm/integer-many-virtual.ll),
its initial log, command, and compiler identity are retained unchanged. This is a
constructed LLVM IR probe, with no C source or preprocessing stage. No MIR is
available before the DAG-building abort. The [baseline replay](../defects/evidence/2026-09-25-aarch64-asm-type/baseline-replay.log)
verifies the preserved binary hash and repeats `Value type is non-standard value, Other.`

The original compiler includes prior patches through 0041; it is not an
unpatched upstream binary. Its complete AArch64ISelLowering.cpp is byte-identical
to saved published upstream revision `742d554bf08042b8df93d791c335260fadd16643`.
The older vendor file differs elsewhere, but the affected `r`/`x` handlers match.
[Identity and source archives](../defects/evidence/2026-09-25-aarch64-asm-type/baseline-identity.json)
retain that distinction. No latest-upstream check is claimed.

The preserved 0057 compiler also fails the same input for the same reason.
The [candidate](../defects/evidence/2026-09-25-aarch64-asm-type/candidate-identity.json)
replaces only AArch64ISelLowering.cpp.o in that compiler's link. The
[diagnostic runner](../../dev/check-aarch64-asm-type-diagnostic.py) requires compiler
exit 1 with exactly the expected diagnostic and returns zero only on success.
Its target, optimization, verifier, and stop-after settings match the recorded
baseline. The original input's bytes are identical in the red and green runs.

## Validation and dependencies

| Check | Result |
|---|---|
| Original input, both preserved compilers | Same unknown-type abort |
| Original input, 0058 candidate | Clean allocation diagnostic; runner passes |
| Eight rejected operand forms, O0/O2, default/+ls64 | 32 aborts on each baseline; 32 clean diagnostics on candidate |
| Supported register, memory, and named-clobber controls | All four configurations pass on all three builds |
| AArch64/ARM/X86 asm, callbr, and LS64 tests, plus new regression | 277 pass; four existing expected failures |
| Patch application to vendor and saved upstream source | Exact candidate source and regression reproduced |

[Individual runs](../defects/evidence/2026-09-25-aarch64-asm-type/operand-matrix.json)
and [suite results](../defects/evidence/2026-09-25-aarch64-asm-type/validation-summary.json)
are retained. The first matrix expectation used the older vendor's diagnostic
wording; the saved upstream compiler says `could not` instead of `couldn't`.
The corrected expectations accept those two exact spellings without accepting
an abort or an unrelated error. The initial results remain available. The first
lit invocation could not start sandboxed multiprocessing workers; the permitted
retry completed the suite.

The `callbr` tests consume results on both edges. Their error recovery depends
on the generic repair in [0057](2026-09-25-selectiondag-inlineasm.md), so an upstream
submission with this full regression needs that recovery prerequisite. The
AArch64 guard itself applies independently. Submission preparation and independent
review remain; this patch has not been published.

A [guard-only link](../defects/evidence/2026-09-25-aarch64-asm-type/recovery-dependency.json)
with the original SelectionDAG archive confirms this distinction: the original
input receives a clean diagnostic, while the `callbr` output diagnoses and then
segfaults during recovery. Including 0057 makes that same `callbr` case exit cleanly.

The tested compiler is retained at `build/aarch64-asm-type-fix/llc` with its
[build recipe](../defects/evidence/2026-09-25-aarch64-asm-type/build-candidate.py).
The installed MOS compiler is configured with only the MOS backend; this
AArch64-only source change does not require rebuilding that compiler. Runtime
execution is not applicable to the rejected inputs.

The document-impact review updated TODO, the pending-work tracker, contribution
status, the earlier investigation's follow-up, and both generated browser views.
Other transitive references describe earlier work or generic tracker navigation;
they do not assert the disposition of this newly captured type failure. Their
historical claims and attribution are preserved.
