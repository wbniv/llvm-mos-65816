# [MOS] Accept an optional BRK signature operand

<!-- RE-SYNCED 2026-09-14: H1 = published title, body below = the published description
     (docs/pr-revisions/2026-09-13/586-body.md) at branch head `a2f81a87b01c` (heads.json).
     Fork-patch follow-ups: docs/plans/2026-09-14-fork-patch-followups.md. Original banner follows. -->
<!-- POSTED: https://github.com/llvm-mos/llvm-mos/pull/586
     Branch: wbniv:mos-brk-signature-operand
     Commit: 064d33fc43ca
     Fork carry: patches/llvm-mos/0024-mos-brk-signature-operand.patch
-->

Accept `brk #imm` as assembler syntax for the BRK opcode followed by a signature byte. Bare `brk` continues to emit one byte.

The signature form is assembler-only. Disassembly always decodes BRK as an operandless, one-byte instruction and treats the following byte independently.

Prior art: ca65 documents an optional BRK signature byte (`brk`, `brk $34`, `brk #$34`) and emits one byte when it is omitted ([ca65 manual, section 4](https://cc65.github.io/doc/ca65.html#ss4.1)). This change accepts only the `#imm` spelling.

Tests cover encoding, object disassembly on MOS6502 and W65816, and disassemble/reassemble round trips. The signature byte in the round-trip test is the NOP opcode, so consuming it as part of BRK would fail the test.

Validation: all 40 MOS MC tests pass (Linux, assertions enabled).
