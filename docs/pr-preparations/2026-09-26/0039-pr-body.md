# [MOS] Honor an explicit width modifier on a constant operand

The assembly matcher honors a symbolic operand's explicit width but can ignore
it after folding a constant. `lda mos16(240),x` becomes zero-page,X instead of
absolute,X; `lda mos24(1193046)` becomes a zero-page load with the address
truncated. This changes addressing semantics, not just instruction size.

Require the modifier's width to fit the candidate operand before accepting its
constant value. The rule already applies to unresolved symbols. Preserve the
special immediate-width handling, extraction modifiers, and unmodified constants.
If the CPU has no matching wide instruction, diagnose the operand instead of
silently truncating it. No native-width or SNES feature is introduced.

Three MC tests cover 6502 and 65816 width selection, zero and negative constants,
extraction modifiers, unchanged bare operands, and unsupported-width diagnostics.
A separate stock-6502 emulator check uses X=$10 and different values at $0000
and $0100. The identical `lda mos16($f0),x` source prints W and exits 7 on the
baseline, versus the expected P and exit 0 with this patch. Its instruction
changes from `b5 f0` to `bd f0 00`. Both objects are relocation-free.

On llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34`, the isolated
assertion-enabled build passes all three new regressions and the full MOS
CodeGen/MC suites: 134 passed, one unsupported, no failures. No other candidate
patch is applied. Earlier broad modifier-sweep evidence remains separately
dated; these are fresh exact-artifact checks. Unposted.

Earlier implementation credits are retained in repository history; this is
submission preparation, not a new-discovery claim. Preparation: OpenAI Codex
CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified
session `01a0db16-f6a0-7e32-ada6-0c8098813933`. Independent review and emulator
validation: OpenAI Codex CLI 0.157.1, model `gpt-6-astra`, `xhigh` reasoning
effort; session `01a0db96-e0ef-75e2-89ad-2939c4954446`.
