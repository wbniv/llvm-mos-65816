# SelectionDAG inline-assembly vector parts

Patch [0059](../../patches/llvm-mos/0059-llvm-selectiondag-vector-asm-parts.patch)
repairs the [vector part-type assertion](../defects/selectiondag-inline-asm-vector-parts.json).
Incompatible vector/register combinations now produce normal compiler diagnostics.
Supported vector conversions still compile. The generic change is included in
the rebuilt and installed MOS Clang and LLD.

Diagnosis, implementation, validation, and documentation: OpenAI Codex CLI
0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, verified
from [session metadata](../defects/evidence/2026-09-25-aarch64-vector-asm/session-identity.json).

## Contract and repair

SelectionDAG selects a register class from the inline-assembly constraint, while
its generic vector converters use the target's normal vector breakdown. Those
two choices can disagree. For example, AArch64's `r` constraint selects scalar
general-purpose registers for vectors that normally use SIMD register parts.
The generic split and join helpers asserted that the part counts and types
matched. A single-part input could instead assert when its scalar register was
too small for the vector.

The converters now diagnose incompatible part counts/types and lossy single-part
conversion, and provide correctly typed undef values for error recovery. The
target's custom split/join hooks still run first. The diagnostic helper recognizes
both ordinary inline-assembly calls and `callbr` (`asm goto`).

Rejecting every large vector in AArch64's constraint handler would discard
supported paths. Equal-width vector/scalar bitcasts, scalarized vectors with
NEON disabled, floating-point inputs, and LS64's 512-bit register class remain
accepted. This repair defines failure behavior for unsupported conversions; it
does not introduce a new ABI or promise arbitrary vector support for `r`.

## Preserved baseline and causality

The [original input](../defects/evidence/2026-09-25-selectiondag-inlineasm/asm-many-virtual.ll)
loads `<64 x i64>` and supplies it to an `r` input. Its input bytes, baseline
record, compiler, and initial diagnostic log are unchanged. This is constructed
LLVM IR: there is no C source or preprocessing stage, and the abort precedes
MIR emission. The [replay](../defects/evidence/2026-09-25-aarch64-vector-asm/baseline-replay.log)
checks the compiler hash and repeats `Part type doesn't match vector breakdown!`.

The baseline compiler includes 0057 and earlier patches; it is **not an unpatched
upstream binary**. Before 0057, the same input hits the separate finite-class
iterator assertion. Thus 0057's virtual-allocation repair is a prerequisite for
this original regression. The affected conversion helpers were unchanged by
0057, and the complete pre-0057 source matches saved published upstream revision
`742d554bf08042b8df93d791c335260fadd16643`. [Source provenance](../defects/evidence/2026-09-25-aarch64-vector-asm/source-provenance.json)
records this distinction; no latest-upstream comparison is claimed.

The preserved 0058 compiler also aborts for the same reason. The new
[candidate](../defects/evidence/2026-09-25-aarch64-vector-asm/candidate-identity.json)
changes only SelectionDAGBuilder.cpp's object relative to that predecessor.
The [runner](../../dev/check-vector-asm-diagnostic.py) uses the original input
and configuration, requiring compiler exit 1 with exactly the vector-parts
diagnostic. Both preserved compilers fail the runner; the candidate passes.
The full compilation also exits normally, sometimes reporting register pressure
in addition to the conversion diagnostic for the oversized operand.

## Validation

| Check | Result |
|---|---|
| Original input, recorded O0/finalize-isel configuration | Both preserved compilers abort; candidate diagnoses normally |
| Input, output, tied, indirect output, and callbr forms at O0/O2 | 30 crashing configurations now diagnose; six existing rejection controls remain rejected |
| Supported vector forms, O0/O2 | All six configurations pass on predecessor and candidate |
| AArch64/ARM/X86 asm, callbr, and LS64 suites plus regressions | 278 pass; four existing expected failures |
| MOS code-generation and MC suites after rebuild | 173 pass; two unsupported |
| Patch application against vendor and upstream-based 0057 source | Exact candidate source and test reproduced |

The [regression](../defects/evidence/2026-09-25-aarch64-vector-asm/inline-asm-vector-parts-formatted.ll)
isolates each rejected operand. Callbr results are consumed on both edges.
[Individual form runs](../defects/evidence/2026-09-25-aarch64-vector-asm/forms-summary.json),
[supported controls](../defects/evidence/2026-09-25-aarch64-vector-asm/positive-summary.json),
and [suite results](../defects/evidence/2026-09-25-aarch64-vector-asm/validation-summary.json)
retain the evidence. Runtime execution is not applicable to rejected IR.
The initial sandboxed lit invocation could not start multiprocessing workers;
the permitted run completed successfully.

The assertion-enabled cross-target compiler is retained at
`build/selectiondag-vector-parts-fix/llc`, with its [build recipe](../defects/evidence/2026-09-25-aarch64-vector-asm/build-candidate.py).
The MOS compiler was rebuilt and Clang/LLD installed;
[binary identities](../defects/evidence/2026-09-25-aarch64-vector-asm/installed-identity.json)
record those artifacts. No additional full worktree was created.

## Submission and document dependencies

Independent review and generic LLVM submission preparation remain. The full
original regression requires 0057; 0058 is retained in the tested stack but does
not repair this vector conversion contract. No PR has been posted for 0059.

The document-impact review updates TODO, pending work, contribution status,
the earlier investigations' follow-ups, and both generated status views.
The rendered report keeps session and diagnostic transcripts collapsed.
Earlier evidence and attribution remain intact. The structured inventory now
contains ten fixed defects and one reentrant contract clarification; unconfirmed
candidates still need evidence before choosing a fix.
