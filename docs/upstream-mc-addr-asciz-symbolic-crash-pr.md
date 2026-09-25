# [MOS] Preserve symbolic .mos_addr_asciz directives in text output

`llvm-mc -show-encoding` aborts on `.mos_addr_asciz _start, 5` with
`Don't know how to emit this value.` The generic text streamer's integer data
directives cannot represent an unresolved decimal-ASCII field of arbitrary
width. Object emission already handles the directive through a dedicated
`MOSMCELFStreamer::emitMosAddrAsciz` fixup.

For a symbolic expression and a streamer with raw-text support, print
`.mos_addr_asciz <expression>, <character count>` directly. This preserves the
directive's semantics and permits reassembly. Constant output and the object
streamer retain their existing paths.

Keep `VK_ADDR_ASCIZ` internal. It is a marker consumed and unwrapped by
`MOSMCELFStreamer::emitValueImpl`, not a general expression modifier. Giving it
an `addrasciz()` spelling also teaches the parser to accept expressions such
as `lda addrasciz(symbol)`, incorrectly attaching a variable-length ASCII fixup
to a one-byte instruction operand. No modifier-table or integer-evaluation
change is needed for the directive's text-output fix.

Tests cover the original symbolic text-output case, byte-for-byte object
round trips at all eight supported character counts, computed and
forward-defined constants, and label differences. A negative test keeps
`addrasciz()` out of instruction operands. The object comparison checks both
section data and relocations; it is stronger than checking one printed line.

The revised patch applies standalone to pinned upstream
`8be0546128a55e78c63ca571d466aa72a782cd36`, without 0039. Integrated MOS
regressions pass with the same four documented fork-suite failures.
[Review and current validation](pr-preparations/2026-09-25/claude-batch-review.md);
[initial pinned-base evidence](pr-preparations/2026-09-25/0047-validation.md).
The latter records the initial implementation and is explicitly superseded
where it describes the removed modifier and evaluation changes.

The directive was introduced by
[6cbcc49](https://github.com/llvm-mos/llvm-mos/commit/6cbcc49db9b2903bf78d78d207da150d53e8cf39).
This compiler fix is independent of the SNES platform submission.

Assisted-by: Claude Fable 5.1, credited in `6eced8e4`, for the initial fix;
Claude Code CLI using Claude Sonnet 5 (`claude-sonnet-5`, `high` reasoning
effort) for pinned-base validation and the initial PR draft; OpenAI Codex CLI
0.155.1 using GPT-6 Astra (`gpt-6-astra`), `xhigh` reasoning effort, for
independent review, narrowing the patch, expanded tests, and this revision.
