Add the W65816 COP instruction with a mandatory signature operand, following WDC assembly syntax. COP encodes as opcode $02 followed by the signature byte and disassembles as a two-byte instruction.

Tests cover expression and literal operands, instruction encoding and disassembly, rejection on an unsupported CPU, and rejection of a missing operand. Comments describe the operand requirement without repeating instruction semantics.

Validation: all 40 MOS MC tests pass (Linux, assertions enabled).
