# 65816 BRL follow-up assessment

Checked 2026-09-20 against upstream `742d554bf08042b8df93d791c335260fadd16643`.

The queue proposed extending PR #550's branch-range gate to `HasW65816`, claiming
that removing JMP trampolines would save bytes and cycles on SNES. Its prerequisites
have merged: [#549](https://github.com/llvm-mos/llvm-mos/pull/549) on August 15 and
[#550](https://github.com/llvm-mos/llvm-mos/pull/550) on August 22.

That does not establish a useful 65816 optimization:

- `MOSAsmBackend::relaxInstructionTo` permits BRA → BRL on W65816, but rejects
  conditional-branch relaxation. The 65CE02 has long conditional branches; the
  65816 does not. Extending the gate for BR/GBR would allow unencodable branches.
- Extending only BRA would replace an absolute JMP with BRL. Both are three bytes.
  The [WDC datasheet](https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf),
  opcode table and bus-cycle tables, gives absolute JMP three cycles and BRL four.
- `JMP` in `MOSInstrLogical.td` expands to `JMP_Absolute`, not the four-byte long
  jump. The hypothesized size benefit does not apply to that replacement.

`getInstSizeInBytes` also uses conservative sizes for some pseudos. A branch that
looks distant before MC lowering could still fit the short form afterward; better
size estimation or deferred relaxation might save a byte in those cases. That is a
separate, unmeasured opportunity and would need a corpus/cycle assessment. This note
does not establish zero possible savings across every program.

Decision: do not prepare the proposed blanket gate-extension PR on this premise. Any later proposal
needs a separate benefit (for example a demonstrated position-independent-code
requirement) and its own correctness and cost evaluation. No compiler change is
proposed here. The blanket claim that every SNES ROM shrinks is withdrawn.

Fresh upstream-tool verification: both variants have 132-byte `.text` sections (three-byte branch/jump, 128-byte gap, RTS). BRA relaxes to `82 80 00`; absolute JMP remains three bytes. See [results](brl-cost-results.txt) and [validation](validation.md).
