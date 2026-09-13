Accept `brk #imm` as assembler syntax for the BRK opcode followed by a signature byte. Bare `brk` continues to emit one byte.

The signature form is assembler-only. Disassembly always decodes BRK as an operandless, one-byte instruction and treats the following byte independently.

Tests cover encoding, object disassembly on MOS6502 and W65816, and disassemble/reassemble round trips. The signature byte in the round-trip test is the NOP opcode, so consuming it as part of BRK would fail the test.

Validation: all 40 MOS MC tests pass (Linux, assertions enabled).
