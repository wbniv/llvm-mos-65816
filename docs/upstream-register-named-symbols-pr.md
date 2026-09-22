# [MOS] Quote register names used as assembly symbols

Generated assembly for a global named `s`, `x`, or `y` is rejected by the
assembler. For example, `unsigned char x; unsigned char f(void) { return x; }`
emits `lda x`, where the operand parser recognizes a register token instead of
the symbol. Quoting the operand as `lda "x"` assembles correctly, but the
instruction printer removes those quotes again.

The ambiguity can also change an instruction silently. `asl "a"` addresses a
memory symbol; printing it as `asl a` makes reassembly select the accumulator
opcode. This affects both `mos6502` and `mosw65816`. The latter also has the
stack-relative case `lda "s",s`, whose symbol must remain distinct from the
register after the comma.

Populate `MOSMCAsmInfo`'s reserved identifiers with register spellings and
operand aliases so symbols retain their quotes. Include both `llvm_mos_`
prefixed names and their unprefixed aliases, imaginary registers, and the
additional `sp`, `r`, `rp`, `ya`, and `psw` tokens. Own the lowercase spellings
in a `StringSet` so the reserved-identifier references remain valid. Register
operands continue to use the existing syntax.

Add two MC tests covering case variants, addends, indexed and indirect
addresses, stack-relative addresses, labels, directives, and the memory versus
accumulator distinction. Both compare direct and reassembled object files.
Add a CodeGen test for register-named globals that also compares direct object
generation with assembly followed by reassembly. Update the existing printer
test's expected spelling of the symbol `z`.

Validation against llvm-mos `742d554bf08042b8df93d791c335260fadd16643`:

- With this patch alone and assertions enabled: 84 MOS CodeGen tests pass,
  one existing test is unsupported, and all 48 MOS MC tests pass. All three
  new regression files fail their output checks with the unpatched tools.
- A reduced C input passes MachineVerifier and produces identical direct and
  reassembled objects at `-O0`, `-O2`, and `-Os` on both CPUs.
- An additional sweep of 2,622 register spellings and case variants produces
  identical direct and reassembled objects on each CPU.
- Replaying 61 assembly failures recorded during copy-expansion testing, with
  that work held constant on both sides, fixes all 61. All backend runs pass
  MachineVerifier, and all direct objects remain byte-identical. Assembly
  changes only in symbol quoting and comment alignment. Of the reassembled
  objects, 59 match direct output byte for byte; the other two differ only in
  the ordering of unreferenced runtime symbols in the symbol table.

- The whole gcc `c-torture/execute` corpus (1,390 files at `-O0`, `-O2` and
  `-Os`), printed with `llc -S` and reassembled with `llvm-mc`: no assembler
  failures (61 before this change), 1,078 compilations change only by quoting,
  and every reassembled object matches the direct object in all section
  contents, relocations and symbols; 113 differ only in symbol-table order.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`,
`xhigh` reasoning effort) for diagnosis, implementation, tests, validation,
and PR drafting.
Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the independent review, the call/branch, case and
address-modifier probes, and the full-corpus round trip.
