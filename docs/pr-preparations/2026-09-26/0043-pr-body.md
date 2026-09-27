# [MOS] Reject inline-asm operands wider than a named data register

An inline-asm constraint naming one eight-bit MOS data register must not accept a wider operand. The value-based register-count hook reports one register for i16, but that does not make A, X, or Y a sixteen-bit register. Accepting the constraint can discard the high byte.

Guard `a`, `x`, `y`, `R`, and `d` by their eight-bit width. Also check the actual class returned by explicit-register lookup: `{rc0}` holds one byte while `{rs0}` holds two. Reject a value wider than the named register rather than treating adjacent registers as an implicit pair. Preserve untyped clobbers, supported condition-code outputs, and Imag16 selection for a normal i16 `r` constraint.

Explicit names can arise from C register variables, even where the frontend rejects a plain wide `=a` constraint:

```c
unsigned short f(void) {
  register unsigned short v __asm__("a");
  __asm__("lda #42" : "=r"(v));
  return v;
}
```

The regression includes positive byte, pair, flag, and clobber cases and twelve invalid named/single-letter input/output cases. The submission test checks the current upstream clean rejection diagnostic, not the older fork's fatal-error wording. Compiler changes are the existing reviewed 0043 repair. This is independent of native-width features and SNES platform work. Unposted.

Earlier recorded credits: Claude Opus 5 (1M context; actual tool/version, exact model ID/version, and reasoning effort unknown) for the initial implementation; Claude Code CLI (version unknown), model `claude-sonnet-5`, `high` reasoning effort for initial pinned-base validation/drafting; OpenAI Codex CLI 0.155.1, model `gpt-6-astra`, `xhigh` reasoning effort for the named-register extension, independent review, and tests. Their original records remain unchanged. Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.

Validation: an isolated Release build with assertions enabled on llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes 14 focused regression RUN commands and the full MOS CodeGen/MC suites: 132 passed, one existing unsupported test, no failures. No other candidate patch is applied. The same regression fails on the preserved baseline and passes with this change. Exact input, patch, binary hashes, and logs are retained in the local packet.
