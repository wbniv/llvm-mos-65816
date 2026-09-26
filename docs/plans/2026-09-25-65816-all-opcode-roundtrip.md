# Exhaustive 65816 assembly/disassembly roundtrip tests

Status: planned; implementation has not started. This change writes the plan
only, as requested. The implementation goal is a reproducible test covering every
65816 opcode through assembly, disassembly, and reassembly, with independently
checked bytes, operands, and instruction boundaries.

Planning and source inspection: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort. Verified from the current turn's session
metadata, session `01a0d7d4-5da2-7fe0-a88c-0137eaa043a7`.

## Existing material and gaps

- [all-65816-opcodes.s](../../vendor/llvm-mos/llvm/test/MC/MOS/all-65816-opcodes.s)
  contains 97 distinct opcode-byte encoding checks and an assembly-only RUN line.
  Inherited instructions are tested in other CPU files. These checks do not
  establish exhaustive 65816 roundtrip coverage.
- [dev/roundtrip.sh](../../dev/roundtrip.sh) compares direct compilation with
  assembly-text reassembly over C fixtures in three compiler configurations.
  It exercises AsmPrinter/parser compatibility, without a disassembly stage or
  an all-opcode coverage requirement. Keep it as a separate integration gate.
- The committed [opcode oracle](../refs/65816/oracle-65c816-opcodes.tsv) contains
  255 unique opcode rows and omits `$42` (WDM). Its current SHA-256 is
  `33410d53507e66666d58d06e339579f5633a39eb4d8879814e65fac364eb8963`.
  [Source provenance](../refs/65816/SOURCES.md) describes the CC0 transcription.
  The existing [TableGen audit](../refs/65816/65816-opcode-audit.md) compares
  descriptions; it does not execute the assembler or disassembler.
- [MOSDisassembler.cpp](../../vendor/llvm-mos/llvm/lib/Target/MOS/Disassembler/MOSDisassembler.cpp)
  obtains 16-bit immediate context from ELF mapping symbols `$ml`, `$mh`, `$xl`,
  and `$xh`. Its width state starts at 8/8; it does not simulate REP/SEP, PLP,
  RTI, or XCE. Raw `llvm-mc -disassemble` alone therefore cannot establish all
  four width contexts. Compiler features `+mos-a16`/`+mos-xy16` are not a substitute
  for verifying the disassembler's actual mode input.
- [brk-signature.s](../../vendor/llvm-mos/llvm/test/MC/MOS/brk-signature.s)
  deliberately decodes BRK as one byte and its signature as another instruction,
  including for `mosw65816`. A byte-preserving roundtrip can pass while instruction
  boundaries disagree with the architectural oracle. Preserve and investigate
  that contract explicitly; do not hide it with a specially convenient signature.

Use the manufacturer's [W65C816S datasheet](https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf)
(March 13, 2024), especially Table 5-4 on page 31 and the instruction descriptions,
to review opcode identity, addressing modes, and width rules. Its matrix includes
WDM and gives BRK/COP their signature-byte lengths. Retain factual normalized
expectations and source citations; the tests must run offline.

## Coverage and success contract

Require exactly the opcode set `$00` through `$ff` in each native width context:

| Context | M flag | X flag | Accumulator immediate | Index immediate |
|---|---|---|---|---|
| a8/x8 | 1 | 1 | 8 bits | 8 bits |
| a16/x8 | 0 | 1 | 16 bits | 8 bits |
| a8/x16 | 1 | 0 | 8 bits | 16 bits |
| a16/x16 | 0 | 0 | 16 bits | 16 bits |

This gives **1,024 mandatory opcode/context cases**, plus operand-boundary and
mode-transition cases. Width-independent instructions remain present in every
context; duplicate rows cannot compensate for a missing opcode. Report per-mode
coverage separately from the number of successful assertions.

For each case, require all of the following:

1. Assembly produces the independently specified opcode and operand bytes.
2. Disassembly consumes the specified instruction length, identifies the expected
   instruction/addressing form, and preserves every operand and its width.
3. Reassembling the disassembler's instruction text produces identical bytes.
4. A second disassembly preserves the same boundaries and canonical operands.

Compare section bytes, not entire ELF files: symbol tables and mapping-symbol
names need not be byte-identical. Check mapping-symbol meaning and offsets
separately. Accept documented mnemonic aliases through an explicit equivalence
table, while requiring addressing mode, width, operands, and bytes to agree.

No skipped opcode, unexpected diagnostic, crash, `<unknown>` instruction, or
`.byte`/`.word` decoding fallback counts as coverage. A byte-equal BRK-plus-another-
instruction rendering does not establish the architectural two-byte BRK boundary.
Any unresolved contract mismatch must remain visible and prevent claiming a fully
passing architectural suite. This is encoding/decoding coverage, not validation
of instruction execution, cycle counts, or complete runtime status tracking.

## Implementation sequence

### 1. Establish the independent case catalogue

Create a reviewed, deterministic catalogue containing opcode, canonical mnemonic,
addressing mode, fixed/M-dependent/X-dependent length, operand values, expected
bytes, and permitted printed aliases. Start from the committed oracle, explicitly
add WDM with its source citation, and audit signature and width rules against the
manufacturer's reference. Do not derive expected bytes from TableGen, current
assembler output, or current disassembler output.

Keep factual instruction information distinct from MOS syntax choices such as
`mos16()` and `mos24()`. Validate opcode uniqueness, mode completeness, byte ranges,
length calculations, and the mandatory 1,024-case count before running tools.
If the shared oracle or its normalization changes, regenerate and review its
existing reference/audit consumers as a separate, visible part of that change.

### 2. Prove the width-context and extraction mechanisms

Build a small prototype for all four contexts before generating the full suite.
Use `llvm-mc -triple mos -mcpu=mosw65816 -filetype=obj`, followed by
`llvm-objdump -d --mcpu=mosw65816`, so the disassembler receives ELF mapping symbols.
Select immediate widths explicitly in the assembly, including small 16-bit values
that require `#mos16(...)` to retain their width.

Check the symbols emitted by
[MOSMCELFStreamer.cpp](../../vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSMCELFStreamer.cpp)
against the catalogue's expected context. Also construct independent decoding
objects from known bytes and explicitly supplied mapping symbols: an incorrect
assembler and incorrect decoder must not validate each other's width mistakes.
Seed both flags where necessary and reset each isolated case's context.

Use raw `llvm-mc -disassemble` for the default-context cases it can represent.
Do not assume instruction bytes alone convey a caller's unknown M/X state.
Exercise mixed-width streams, mapping-symbol changes, and section boundaries
without assuming that linear disassembly executes status-changing instructions.

Extract instruction text with a strict parser that validates addresses, consumed
byte counts, and instruction counts before removing display columns. Preserve
width modifiers. For PC-relative operands, preserve or reconstruct labels at
their checked addresses; do not turn an absolute target address into a displacement
by blindly stripping objdump formatting.

### 3. Build the exhaustive gate and focused regression fixtures

Proposed implementation artifacts, with final filenames chosen to fit LLVM's
test layout:

- `llvm/test/MC/MOS/all-65816-roundtrip.s`: the lit entry point and focused readable
  examples of the contract.
- `llvm/test/MC/MOS/Inputs/65816-opcode-cases.json`: the independent catalogue,
  including source provenance and explicit alias/width rules.
- `llvm/test/MC/MOS/Inputs/check-65816-roundtrip.py`: a deterministic runner using
  lit-provided tool paths, with per-case diagnostics and machine-readable results.
- A repository `dev/` wrapper for the same gate against a chosen build/install,
  if needed for the existing release workflow. It must call the same checker.

Run both directions: catalogue assembly to object to disassembly to reassembly,
and catalogue bytes to disassembly to assembly. Use isolated cases to localize
failures, plus concatenated streams with checked instruction offsets to detect
over-consumption, under-consumption, and mode-state leakage.

Add explicit operand checks for:

- All M-dependent immediate opcodes: ORA, AND, EOR, ADC, BIT, LDA, CMP, SBC;
  all X-dependent immediates: LDX, LDY, CPX, CPY. REP/SEP and signature operands
  retain their fixed widths.
- Immediate values around `$7f`, `$80`, `$ff`, `$0100`, and `$ffff`, including
  16-bit operands whose high byte is zero.
- Direct-page, absolute, and long addresses sharing small numeric values;
  bank-zero long operands; indirect, indexed, long-indirect, and stack-relative
  forms. Width modifiers must prevent narrowing to another opcode.
- Distinct bytes such as `$12/$34/$56` to expose little-endian operand ordering;
  unequal source/destination banks for MVN/MVP. Preserve the existing
  [block-move tests](../../vendor/llvm-mos/llvm/test/MC/MOS/65816-block-move-bank-order.s).
- Positive and negative branch displacements, signed range endpoints, and BRL/PER;
  compare resolved target addresses and encoded displacement bytes.
- BRK, COP, and WDM with several signature values; WAI/STP; accumulator/implied
  forms; long jumps and their aliases. Keep the existing
  [long-address roundtrip tests](../../vendor/llvm-mos/llvm/test/MC/MOS/long-address-roundtrip-65816.s).

Test the checker itself with intentional missing/duplicate opcode rows, changed
operand bytes, swapped block-move banks, wrong decoded widths, extra decoded
instructions, and tool failures. Every mutation must fail for its specific reason.

### 4. Capture failures before repairing compiler code

Run the new cases against the preserved current tools and record their binary
hashes, source revision plus dirty changes/patch stack, command lines, tool
versions, catalogue hash, and results. Keep exact assembly, reference bytes,
objects, disassembly, and reassembled bytes for each failure. No compiler IR/MIR
or preprocessing stage is expected for a direct MC failure; say so explicitly.

Follow the [defect evidence workflow](../howto-defect-evidence.md) for each newly
confirmed defect. Preserve the initial BRK contract discrepancy and distinguish
an intentional formatting policy from an encoding error. Do not rewrite the
oracle to match the implementation or silently exempt the discrepancy.

If compiler repairs are needed, retain the same failing input on the baseline,
make the smallest causally justified repair, and rerun it on the identified
candidate. Carry focused regressions with each fix. The existing 6502 BRK behavior
must be assessed separately from the 65816 signature contract.

For upstream claims, validate the relevant cases on a separately identified,
published upstream baseline. Record a saved revision as saved, and a patched
compiler as patched. Local passage alone does not establish current upstream
behavior or submission readiness.

### 5. Integrate, validate, and record completion

Carry vendor changes in a reproducible patch, update `dev/toolchain.sh`, and
register the appropriate patch-regeneration inputs. Run the new gate and the
full MOS MC suite; run MOS code-generation tests and the existing C roundtrip
gate when shared parser/printer or compiler behavior changes. Verify patch
application and that the chosen tools actually contain the tested changes.

The implementation is complete only when all 256 opcodes in all four contexts
pass independently checked encoding, decoding, boundaries, and roundtrip checks;
the supplemental cases pass; and the checker rejects its negative controls.
No blanket XFAIL or filtered coverage can satisfy that requirement.

Retain a concise result summary listing toolchain identities, coverage counts,
operand-case counts, exact invocation, results, and any remaining limitations.
Use the existing build where possible; avoid another full LLVM worktree and keep
failing evidence intact. A full emulator or SNES runtime is not required for this
MC-only gate. Test work does not depend on the SNES platform submission.

## Work and document dependencies

The implementation order is: reviewed oracle → validated context/extraction
prototype → exhaustive checker → preserved baseline results → any required
compiler repairs → integrated validation and completion record. Evidence capture
must precede repairs; independently checked bytes must precede roundtrip claims.

[TODO](../../TODO.md), [pending work](../upstream-pending-work.md), and
[contribution status](../upstream-contribution-status.md) track this as planned
test coverage. Their explicit dependency on this plan belongs in
[document-dependencies.json](../document-dependencies.json); their rendered status
and flowchart views must follow the same disposition. Follow the
[document dependency workflow](../howto-document-dependencies.md) when this plan
or its results change. Register any new generated catalogue/report with its
generator, oracle, and tool-result inputs; do not label hand-written expectations
as generated from the compiler under test.

Upstream preparation and publication remain separate from implementing the gate.
Reassess actual patch prerequisites after baseline testing; do not assume every
existing local width/signature patch is required merely because it is installed.
