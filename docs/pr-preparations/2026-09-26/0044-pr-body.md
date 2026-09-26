# [MOS] Preserve explicit long addresses in printed assembly

The assembler distinguishes direct-page, absolute, and absolute-long addressing.
Printing an absolute-long operand as an unqualified small integer or bare symbol
loses that choice: parsing the text can select a narrower opcode. This changes
the address used, not just the spelling of the instruction.

```
$ llvm-mc -triple mos -mcpu=mosw65816 -disassemble <<< '0xaf,0xf0,0x00,0x00'
	lda	240        ; reassembles as a5 f0     (was af f0 00 00)
$ llvm-mc -triple mos -mcpu=mosw65816 -disassemble <<< '0x5c,0xf0,0x00,0x00'
	jmp	240        ; reassembles as 4c f0 00  (was 5c f0 00 00)
```

The far load becomes a direct-page read of an unrelated address, and the long
jump becomes a bank-local one. Branch displacements are then recomputed over the
shorter code, so the result assembles cleanly and is silently wrong. Any flow
that reassembles printed output hits this, including `-save-temps`.

The gap dates from the introduction of 65816 long addressing,
[`19ea9eab`](https://github.com/llvm-mos/llvm-mos/commit/19ea9eab486f7bd784f2c4b80cba759044ca5740)
("Add MC instructions, relocations, and disassembler support for 65816"), which
added the `AbsoluteLong`/`AbsoluteXLong` forms and the `addr24` operand without
a print method.

Print operands of absolute-long and absolute-long,X instructions through an
explicit `mos24(...)` wrapper. Long `JSL`/`JML` operands use the same printer.
Immediate values retain the immediate printer, so this does not turn data into
addresses or add native-width feature support.

The MC regression disassembles low-valued long addresses and reassembles the
text, checking that the bytes and addressing modes survive. A MIR-level printer
regression also covers symbolic load/store, indexed-load, and long-call operands.
The latter starts after machine optimization and uses already-supported 65816
instructions; it does not require the downstream far-pointer address spaces.

The MC round-trip regression requires the explicit-width parsing fix (0039).
Measured at the pinned base with this change alone: the printed text is correct,
but reparsing it still narrows. `lda`/`sta mos24(240)` come back as zero-page
`a5 f0`/`85 f0`, and `lda mos24(43981),x` truncates to `b5 cd`. Only `jsl`,
which has no narrower encoding, and constants above `0xFFFF` survive. With 0039
applied as well, both halves of the test pass.
This can be opened as a dependent PR once that prerequisite PR exists; it does
not depend on the SNES platform or native-width compiler submissions.
Validation and exact base/patch identities accompany the local
preparation package; this file is an unposted draft.

Original implementation: commit `5ea5006c`, credited there to Claude Opus 5
(1M context); Claude Code 2.1.278 using Claude Opus 5 (`claude-opus-5`), `high`
reasoning effort, as a subagent, verified from Claude Code session
`65695418-7e9b-45bd-92e3-2ecfd88ecf0b` metadata. The credit is not reassigned.
Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`.
Pinned-base validation (0044 alone and 0039+0044 at `8be0546`) and the breaking
commit: Claude Code 2.1.280, model `claude-sonnet-5`, `high` reasoning effort
(subagent); merged into this draft by Claude Code 2.1.280, model
`claude-opus-5-5`, `medium` reasoning effort (main session; commit `b6a456ea`
names 2.1.283 in error). Verified from session `65695418-7e9b-45bd-92e3-2ecfd88ecf0b` metadata. Record:
[`0044-validation.md`](0044-validation.md).

Validation: an isolated Release build with assertions enabled on llvm-mos main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes 3 focused regression RUN commands
and the full MOS CodeGen/MC suites: 136 passed, one existing unsupported test,
no failures. The baseline includes 0039; adding only this printer repair makes
the same regression pass.
Exact input, patch, binary hashes, and logs are retained in the local packet.
