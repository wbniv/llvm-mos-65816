# [MOS] Reject inline-asm operands wider than a named data register

MOS can silently discard the high byte of a 16-bit inline-asm output constrained
to an 8-bit register. The IR spelling `"=a"` demonstrates the mismatch between
`getNumRegistersForInlineAsm(i16) == 1` and the 8-bit register returned by
`getRegForInlineAsmConstraint`. Explicit names such as `"={a}"` have the same
problem and are also reachable from C:

```c
unsigned short f(void) {
  register unsigned short v __asm__("a");
  __asm__("lda #42" : "=r"(v));
  return v;
}
```

Clang turns this register variable into an `"={a}"` constraint. Without the
check, the assembly contains `lda #42; ldx #0; rts`: the asm defines only the
low byte, and the backend invents the high byte. Ordinary C `"=a"` with a
16-bit operand is already rejected by Clang; the named-register form bypasses
that frontend check.

Guard `a`, `x`, `y`, `R`, and `d` by their eight-bit width. Also check the actual
class returned by generic explicit-register lookup: `{rc0}` holds one byte,
while `{rs0}` holds a full 16-bit value. Reject an operand wider than that
register instead of treating adjacent physical registers as an implicit pair.
Untyped clobbers remain accepted; `c`/`v` condition outputs retain their
extension behavior. The `r` constraint still uses Imag16 for i16.

The hook returns its normal unsatisfiable-constraint result. GlobalISel
currently reports that result as `unable to translate instruction: call`;
this patch does not add a frontend diagnostic or improve that fatal-error path.

The test covers the five single-letter constraints, a wide input, six invalid
explicit names/widths, and valid byte, pair, flag, and clobber cases. The named
register cases fail against the initial 0043 patch and pass with this revision.
The C example is independently checked with the rebuilt driver.

Validation and the earlier isolated pinned-base results are recorded in
[0043 validation](pr-preparations/2026-09-25/0043-validation.md) and the
[September 25 review](pr-preparations/2026-09-25/claude-batch-review.md).
The revised patch applies to the pinned upstream base. New integrated MOS
regressions pass; the four documented fork-suite failures remain.

The two hooks' i16 convention originated in
[f7593f2a15e20243244b2f7fb6b19cebeb717618](https://github.com/llvm-mos/llvm-mos/commit/f7593f2a15e20243244b2f7fb6b19cebeb717618).
This is independent of native 65816 features and SNES platform submission.

Assisted-by: Claude Opus 5 (1M context), credited in `84d87260`, for the initial
implementation; Claude Code CLI using Claude Sonnet 5 (`claude-sonnet-5`, `high`
reasoning effort) for pinned-base validation and the initial PR draft; OpenAI
Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`), `xhigh` reasoning effort,
for independent review, the named-register extension, regression coverage,
and this revision.
