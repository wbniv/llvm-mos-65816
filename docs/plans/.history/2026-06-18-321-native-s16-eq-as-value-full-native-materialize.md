| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/ef4e6db) | #321 EQ-as-value full-native materialize: spike VERIFIED → WON'T-IMPLEMENT (+14 B regression) |

<!--history-meta v1
ef4e6db	author	Will Norris
ef4e6db	added	300
ef4e6db	deleted	0
ef4e6db	files	1
ef4e6db	body	M2 item (c)'s last deferred piece — the "full native one-REP-bracket compare-and-\nmaterialize" for `b = (a == c)` (replace the select-diamond with a branchless flag→0/1).\nSpiked Option A (branchless via native XOR + carry of SBC(0,X)) in an isolated throwaway\nworktree seeded from main's toolchain (no shared vendor/ change). Measured a uniform\n+14 B regression — a16eqval 104→118, a16eqvalc 121→135, a16eqvalp 154→168 — verify-clean.\n\nRoot cause (disasm-confirmed): the backend has NO branchless flag→byte path — the carry\ncopied to the result itself lowers to a control-flow diamond (bcc; ldx#1; stx; bra; stz),\nso "branchless" bolts the value computation (eor; sta; lda#0; cmp) on top of an unchanged\ndiamond. And equality's Z isn't rotatable, so synthesizing a rotatable carry needs the\ndifference/XOR value first (extra native ALU op + Imag16 stash) — costing more than the\none-branch diamond it would replace. The existing operand-folded select-diamond (v1/v2/v3)\nis near-optimal. Option B (a 5-pseudo CmpSel*16 family with a rol tail) is predicted ≥\ndiamond for the same reason — not worth a substantial change to ship a regression\n(governing lessons #2/#3).\n\nPlan §Phase 0 records the table + disasm + root cause (Status → WON'T-IMPLEMENT); TODO\nM2 item (c) dispositioned. Worktree + scratch branch removed; main vendor/ + 0002 untouched.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
