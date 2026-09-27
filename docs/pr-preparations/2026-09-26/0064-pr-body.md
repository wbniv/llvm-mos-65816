# [MOS] Prefer schedules with fewer overlapping computed carries

MOS has one hardware carry flag. Interleaving independent arithmetic chains can require converting a computed carry to a byte and restoring it later. Track computed `Cc` values at both scheduling boundaries and prefer candidates that reduce the number live beyond that capacity, before the existing physical register preferences. Constant carry initializers remain rematerializable. Use defining nodes to distinguish two-address redefinitions, and retain legal schedules when dependencies require overlap.

The stock-6502 MIR regression interleaves a four-byte shift and add. Its code shrinks from **133 to 59 bytes**, removing six carry materializations. The same MIR lowered by either build passes **512 Python-oracle vectors in mos-sim**. The test covers bidirectional, top-down and bottom-up scheduling, plus ordinary 65C02, 65CE02 and 65816 lowering, single chains, necessary overlap, and multiple users. Top-down already passes on the baseline.

Validation uses standalone llvm-mos main `7bd67c0ae4e8bb65a3f980912bf201df22131e34`, with assertions enabled:

- Ten focused commands pass; five scheduling checks fail on the matching baseline.
- Full MOS CodeGen/MC suites: **132 passed, one unsupported, zero failures**.
- Upstream Clang built with and without this patch compiled thirteen C fixtures at `-Os`, `-Oz`, and `-O2` for 6502, 65C02, and stock 65816: **all 117 pairs passed machine verification and produced identical disassembly**. Objects also match byte-for-byte after removing compiler-version metadata. Both builds used the same SDK headers with LTO disabled; the generated IR confirms the requested CPU in every case. [Commands and compiler identities](https://github.com/wbniv/llvm-mos-65816/blob/main/docs/pr-preparations/2026-09-26/validation/runs/carry-0064-upstream-clang/receipt.json).
- Earlier backend comparison: our fork's Clang generated LLVM IR for thirteen near-code fixtures at `-Os`, `-Oz`, and `-O2`. Both upstream backends consumed identical IR: **117 paired invocations produced identical disassembly**. The IR pins functions to `mos6502`, overriding the requested backend CPU; these are **39 distinct 6502 configurations repeated three times**.

Separate downstream measurements show aggregate code-size gains, with retained individual losses of **1–41 bytes**. The largest loss changes frame traffic in an L-system loop; another case adds a native-width mode transition. Those costs are accepted for this size optimization, and should inform review of the heuristic's priority. No universal size improvement is claimed. **Cycles and compile time are unmeasured**, so this PR makes no speed or compiler-overhead claim. Published [BankWalk](https://biohack.net/snes/bankwalk/) and [Dual-LFSR](https://biohack.net/snes/lfsr2/) demos provide downstream integration context; they are not benchmarks of this exact upstream extraction.

The patch changes only the MOS scheduler and its regression test.

This preparation has author review; no independent review is claimed.

Implementation, extraction, author review and validation: OpenAI Codex CLI 0.157.1, model `gpt-6-astra`, `xhigh` reasoning effort. Original downstream sum/rotate inputs and measurements: Claude Code 2.1.278, model `claude-opus-5`, `high` reasoning effort.

[Retained validation](https://github.com/wbniv/llvm-mos-65816/blob/main/docs/pr-preparations/2026-09-26/0064-validation.md) and [profitability review](https://github.com/wbniv/llvm-mos-65816/blob/main/docs/pr-preparations/2026-09-26/0064-review.md).
