# [MOS] Use zero-page indexed opcodes for globals in zero-page sections

An indexed access to a global in `.zp.bss` produces different instructions
depending on the output path. Direct object emission selects `LDA absolute,X`
(`BD 00 00`), but the assembly printer writes `lda mos8(samples),x`, which
assembles as `LDA zero-page,X` (`B5 00`). Both objects use `R_MOS_ADDR8` for the
symbol; the disagreement is in the opcode and instruction size.

Zero-page globals must fit wholly in zero page, so valid accesses based on them
can use the compact indexed form. `lowerOperand` already recognizes the
`.zp`, `.zeropage`, and `.directpage` section families, but
`canUseZeroPageIdx` only recognizes the zero-page address space. Use
`MOS::isZeroPageSectionName` in the indexed-opcode decision too. Also check
operand 1, the address, when lowering `STAbsIdx`; operand 0 is the stored value.

The tests check instruction bytes and compare complete direct and reassembled
objects. They cover indexed loads, stores, arithmetic, shifts, rotates,
increments/decrements, and STZ; section names, aliases, address-space-1 globals,
and symbol offsets; and ordinary globals, numeric addresses, and addressing
forms without a compact opcode.

Validated against llvm-mos `742d554bf08042b8df93d791c335260fadd16643` with
assertions enabled and this change alone:

- All three new tests reproduce the object mismatch without the change and
  pass with it. MOS CodeGen: 86 pass, one unsupported; MC: 46 pass.
- A 45-case C comparison covers `mos6502`, `mos65c02`, and `mosw65816` at
  `-O0`, `-O2`, and `-Os`. All 27 zero-page-section cases now have byte-identical
  direct and reassembled objects. All 18 ordinary-section controls retain
  identical direct objects. Machine verification passes throughout.

- Independent review on an assertion build carrying the other prepared fixes:
  the three tests pass, the MOS suites pass (140, one unsupported), indexed
  accesses with large positive and negative symbol offsets still produce
  identical direct and reassembled objects, and neither the gcc C-torture
  corpus (4,170 backend compilations) nor a 137-program SNES corpus changes a
  single byte, since neither places globals in zero-page sections; the
  downstream emulator gate passes 79 of 79 programs with the change installed.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for investigation, implementation, tests, validation, and
PR drafting.
Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the independent review and the corpus, offset and
emulator-gate checks.
