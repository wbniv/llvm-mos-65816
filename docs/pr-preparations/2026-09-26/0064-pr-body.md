# [MOS] Prefer schedules with fewer overlapping computed carries

MOS has one hardware carry flag. Interleaving independent arithmetic chains
can require converting a computed carry to a byte and restoring it later.
Track computed `Cc` values at both scheduling boundaries and prefer candidates
that reduce the number live beyond that capacity, before the existing physical
register preferences. Constant carry initializers remain rematerializable.
Use defining nodes to distinguish two-address redefinitions, and retain legal
schedules when dependencies require overlap.

The stock-6502 MIR regression interleaves a four-byte shift and add. Its code
shrinks from **133 to 59 bytes**, removing six carry materializations. The same
MIR lowered by either build passes **512 Python-oracle vectors in mos-sim**.
The test covers bidirectional, top-down and bottom-up scheduling, plus ordinary
65C02, 65CE02 and 65816 lowering, single chains, necessary overlap, and multiple
users. Top-down already passes on the baseline.

Validation uses standalone llvm-mos main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34`, with assertions enabled:

- Ten focused commands pass; five scheduling checks fail on the matching baseline.
- Full MOS CodeGen/MC suites: **132 passed, one unsupported, zero failures**.
- Thirteen near-code fixtures, at `-Os`, `-Oz`, and `-O2` for 6502, 65C02, and
  stock 65816: **117 paired object comparisons with identical disassembly**.
  These hold a downstream Clang frontend fixed and compare the current upstream
  backends; they are not measurements of a rebuilt upstream frontend.

Separate downstream measurements show aggregate code-size gains, with retained
individual losses of **1–41 bytes**. The largest loss changes frame traffic in
an L-system loop; another case adds a native-width mode transition. Those costs
are accepted for this size optimization, and should inform review of the
heuristic's priority. No universal size improvement is claimed. **Cycles and
compile time are unmeasured**, so this PR makes no speed or compiler-overhead
claim. Published [BankWalk](https://biohack.net/snes/bankwalk/) and
[Dual-LFSR](https://biohack.net/snes/lfsr2/) demos provide downstream integration
context; they are not benchmarks of this exact upstream extraction.

The patch changes only the MOS scheduler and its ordinary-MOS regression. The
generic TableGen pressure-contract repair, inherited farblit legalization
failure, and unisolated all-XY16 driver observation remain separate follow-ups.

This preparation has author review; no independent review is claimed.

Implementation, extraction, author review and validation: OpenAI Codex CLI
0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified
session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`. Original downstream sum/rotate
inputs and measurements: Claude Code 2.1.278, model `claude-opus-5`, `high`
reasoning effort; session `65695418-7e9b-45bd-92e3-2ecfd88ecf0b`,
agent `a35017d73ff4d881d`.
