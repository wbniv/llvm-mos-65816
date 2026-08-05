| Date | Change |
|------|--------|
| [2026-08-04](https://github.com/wbniv/llvm-mos-65816/commit/4db2f87) | docs(upstream): COP mnemonic + BRK/COP signature byte — implemented, drafted, not posted |

<!--history-meta v1
4db2f87	author	Will Norris
4db2f87	added	213
4db2f87	deleted	0
4db2f87	files	1
4db2f87	body	The MOS assembler had no `cop` at any width and `brk` took no operand, so the\n#140 software-vector demo hand-assembles both traps as .byte. Fixed upstream-side\non mos-65816-cop-brk-signature (61c07100970c, local in ~/llvm-mos, cut from\n1f334fef02b5): ca65-style optional signature byte for both, COP gated on\nFeatureW65816 (opcode $02 is NXT on the 65EL02), strictly additive so bare `brk`\nkeeps its one-byte encoding. MC suite 39/40 with the lone failure proven\npre-existing on pristine upstream; predicate gating and the NXT collision pinned\nby tests.\n\nBranch NOT pushed and PR NOT posted, per instruction — the draft carries the\nexact push + gh pr create commands.\n\nAlso records a side finding as status-doc row 19: llvm-mc.cpp:374 unconditionally\noverrides the MCAsmInfo-derived Motorola-integer setting from a cl::opt defaulting\nto false, so $-hex silently stops working under bare llvm-mc (35 of 39 MOS MC\ntests compensate with -motorola-integers). The real driver is unaffected. Kept out\nof the COP patch deliberately; offered as a footnote in its PR body.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
