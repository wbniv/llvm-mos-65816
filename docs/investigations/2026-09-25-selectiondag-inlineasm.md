# SelectionDAG inline-assembly register bounds

Structured record: [selectiondag-inline-asm-register-bounds](../defects/selectiondag-inline-asm-register-bounds.json).

Reproduction, patch 0057, validation, installation, and documentation: OpenAI Codex CLI 0.157.0
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, verified in the
[session metadata](../defects/evidence/2026-09-25-shift-inlineasm-fixes/session-identity.json).

## Preserved baseline

The [constructed LLVM IR](../defects/evidence/2026-09-25-selectiondag-inlineasm/asm-cc.ll)
requests an i128 output in AArch64's `{cc}` register. There is no C frontend or
preprocessing stage. SelectionDAG requires multiple registers for the value, but
the condition-code class contains only NZCV. Its allocation loop advances past
the class end and asserts. The retained IR is the exact pass input; no MIR is
produced before this DAG-building failure.

The [baseline run](../defects/evidence/2026-09-25-selectiondag-inlineasm/baseline-runner.log)
uses preserved `build/0041-inlineasm-build/llc-0041`, with assertions enabled,
`-mtriple=aarch64 -global-isel=0 -O0 -verify-machineinstrs`. The binary includes
prior patches through 0041, so it is not an unpatched upstream binary. The entire
SelectionDAGBuilder.cpp file is byte-identical to saved published upstream revision
`742d554bf08042b8df93d791c335260fadd16643`; identity, source, full dirty diff, and
configuration references are retained in the structured record. This finding is
independent of the GlobalISel repair in 0056.

Verbatim compiler-source snapshots are stored as gzip archives, with their
uncompressed hashes and byte-for-byte round-trip checks in the
[archive manifest](../defects/evidence/2026-09-25-selectiondag-inlineasm/source-archives.json).
Their existing upstream comments are preserved unchanged. The comment-history
check applies to the authored patch and regression code; it is not relaxed to
accommodate the captured third-party source. The initial snapshot-check failure
is retained alongside the final repository-check results.

## Repair and validation

Patch [0057](../../patches/llvm-mos/0057-llvm-selectiondag-inline-asm-register-bounds.patch)
checks the complete physical-register range before assignment and reports a
register/type mismatch through the existing diagnostic path. Virtual-register
creation does not advance a physical-class iterator. The initial candidate
handled ordinary calls but exposed an additional `callbr` recovery requirement:
the landing pad cannot follow output copies when the rejected asm emitted none.
After a lowering error, that path supplies undefined recovery values, including
aggregate results. Compilation still fails with the diagnostic and produces no
usable output. The initial candidate source and exploratory log are retained;
they are not the final green result.

The [isolated candidate](../defects/evidence/2026-09-25-selectiondag-inlineasm/candidate-identity.json)
changes only SelectionDAGBuilder.cpp.o in the baseline link. The same original IR
passes the [diagnostic runner](../../dev/check-selectiondag-register-diagnostic.py),
which requires compiler exit 1 and exactly the expected message; the runner itself
returns 0. Both the preserved fork source and the saved upstream source accept
their respective patch variants and reproduce the tested source exactly.

| Check | Result |
|---|---|
| Seven isolated forms at O0 and O2 | All 14 baseline runs assert; all 14 candidate runs emit exactly one expected diagnostic |
| AArch64, ARM, X86 inline-asm/callbr tests, plus the new regression | 275 passed; four existing expected failures |
| MOS CodeGen and MC | 173 passed; two unsupported |
| Main llc, Clang, LLD rebuild | Passed; installed Clang and LLD hashes match the rebuilt binaries |

The seven forms are direct output, input, tied input, indirect output, and three
`callbr` variants: an oversized output, an oversized input with a live valid
output, and a mixed aggregate output. Each function runs separately so an earlier
diagnostic cannot mask the branch-recovery behavior. The new lit regression also
checks their combined diagnostics. The cross-target suite uses the preserved
upstream-based source; the new regression runs in a separate lit suite with the
same candidate. [Commands and counts](../defects/evidence/2026-09-25-selectiondag-inlineasm/validation-summary.json)
and [individual red/green runs](../defects/evidence/2026-09-25-selectiondag-inlineasm/operand-matrix.json)
are retained. Runtime tests do not apply to this rejected inline-assembly input.

## Distinct findings and follow-ups

Two constructed oversized-type probes reached different assertions and were
left open by the physical-range repair. They are not application failures.
Subsequent work repairs the integer query in [0058](2026-09-25-aarch64-inlineasm-unknown-type.md)
and the vector conversion assertions in [0059](2026-09-25-selectiondag-vector-parts.md).
Their exact LLVM IR, diagnostics, compiler hashes, and original source identities are retained in separate records:

- [Vector part-type assertion](../defects/selectiondag-inline-asm-vector-parts.json):
  `<64 x i64>` with an `r` input reaches `Part type doesn't match vector breakdown!`
  on the preserved 0057 candidate. The original baseline stops earlier at the
  finite-class iterator assertion. At capture, target constraint support and the
  required conversion or rejection still needed investigation.
  **Follow-up:** 0059 diagnoses incompatible generic vector parts and lossy
  scalar conversion, preserving supported paths. The unchanged original input
  fails on this preserved 0057 compiler and passes the diagnostic runner with
  0059. [Diagnosis, dependencies, and validation](2026-09-25-selectiondag-vector-parts.md).
- [Nonstandard integer type abort](../defects/selectiondag-inline-asm-nonstandard-integer.json):
  `i4096` with an `r` input reaches `Value type is non-standard value, Other.` on
  both builds. This is an earlier type-query failure, independent of 0057.
  **Follow-up:** fixed by 0058's AArch64 unknown-type guards, with the original
  input failing on both preserved builds and receiving a clean diagnostic on
  the identified candidate. [Diagnosis and validation](2026-09-25-aarch64-inlineasm-unknown-type.md).

A separate `<128 x i64>` probe using `w` already receives a normal allocation
diagnostic on both builds. Its passing rejection is a control, not evidence that
either crash is repaired.
