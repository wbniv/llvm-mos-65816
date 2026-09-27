# [MOS] Scalarize floating-point vector arithmetic before libcall legalization

MOS implements supported scalar floating-point arithmetic with library calls. The legalization rule currently selects those calls only for scalar `s32` and `s64` operands. A vector arithmetic instruction reaches the unsupported fallback even though each lane can use the existing scalar operation.

Scalarize the operation's element type before applying the scalar libcall rule. This uses the existing vector legalization infrastructure; it does not introduce a vector calling convention or vector runtime library. The regression passes vectors through pointers and checks one scalar libcall per lane for float/double addition, subtraction, multiplication, division, and remainder.

The submission targets current llvm-mos, which already contains the vector load/store and scalarization prerequisites. The downstream `0049` backport is not part of this change and is not a new upstream contribution. The posting regression uses stock `mos6502`, without downstream native-width feature flags.

Retained matching-input and runtime evidence includes 96 lane comparisons at each optimization level on mos-sim and separate float/double SNES runtime checks. Those are supporting downstream results, not a claim that the pristine upstream tree includes the SNES platform. The local preparation package records isolated upstream-build results separately.

Implementation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; recorded session `01a0d7d4-5da2-7fe0-a88c-0137eaa043a7` in the original investigation. Submission preparation: OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0db16-f6a0-7e32-ada6-0c8098813933`.

Validation: an isolated Release build with assertions enabled on llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34` passes 1 focused regression RUN commands and the full MOS CodeGen/MC suites: 132 passed, one existing unsupported test, no failures. No other candidate patch is applied. The same regression fails on the preserved baseline and passes with this change. Exact input, patch, binary hashes, and logs are retained in the local packet.
