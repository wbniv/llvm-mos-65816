# [MOS] Preserve symbolic .mos_addr_asciz directives in text output

`llvm-mc -show-encoding` aborts on `.mos_addr_asciz _start, 5` because the generic
text streamer's integer directives cannot represent an unresolved decimal-ASCII
field. Object emission already uses the target's dedicated fixup path.

For a symbolic expression and a raw-text streamer, print the original
`.mos_addr_asciz <expression>, <character count>` directive. Leave constant
emission and the object streamer unchanged. Reassembly then retains the field
and its relocations.

Keep VK_ADDR_ASCIZ internal: it is a streamer marker, not a general expression
modifier. No `addrasciz()` language extension or integer-evaluation change is
needed. A negative test ensures instruction operands still reject that spelling.

Regressions cover symbolic text output, all eight supported field widths,
computed/forward-defined constants, label differences, and byte-identical
direct versus reassembled objects. This change does not require 0039, native
compiler support, or a SNES platform submission. Unposted.

Earlier recorded initial implementation: Claude Fable 5.1 (actual tool/version,
exact model ID/version, and reasoning effort unknown). Initial validation and
draft: Claude Code CLI (version unknown), model `claude-sonnet-5`, `high`
reasoning effort. Independent review, narrowing, and expanded tests: OpenAI
Codex CLI 0.155.1, model `gpt-6-astra`, `xhigh` reasoning effort. Original records
and credits are preserved.
Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`.

Validation: an isolated Release build with assertions enabled on llvm-mos main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes 9 focused regression RUN commands
and the full MOS CodeGen/MC suites: 133 passed, one existing unsupported test,
no failures. No other candidate patch is applied. The same regression
fails on the preserved baseline and passes with this change.
Exact input, patch, binary hashes, and logs are retained in the local packet.
