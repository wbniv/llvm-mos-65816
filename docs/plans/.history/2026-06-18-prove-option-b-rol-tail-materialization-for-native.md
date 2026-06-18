| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/e4858eb) | #321 EQ-as-value: prove Option B (rol/adc-tail) is a regression too — WON'T-IMPLEMENT confirmed |

<!--history-meta v1
e4858eb	author	Will Norris
e4858eb	added	111
e4858eb	deleted	0
e4858eb	files	1
e4858eb	body	The full-native-materialize plan's Option B (a CmpSel*16 pseudo with an explicit\nlda #0; rol/adc branchless tail) was "predicted, not built". Proved it empirically in a\nthrowaway worktree, building the branchless tail WITHOUT a new pseudo: selectAddE already\nlowers G_UADDE -> adc, so the EQ value path emits X=LHS^RHS; Ceq=C of SBC(0,X)=(X==0);\nbyte=G_UADDE(0,0,Ceq) -> `txa; adc #0` (confirmed branchless: adc present, no bcc/beq\nmaterialize diamond).\n\nMeasured a LARGER regression than Option A on every shape, verify-clean:\n  a16eqval  104 -> 120 (+16 B)\n  a16eqvalc 121 -> 149 (+28 B)\n  a16eqvalp 154 -> 175 (+21 B)\n\nRoot cause (disasm): the branchless tail itself is cheap (txa; adc #0 = 3 B), but it\nforgoes the CmpBr compare-fusion the diamond exploits. The diamond fuses lda; cmp straight\ninto the branch; the branchless path must form X=LHS^RHS, stash it, and run a standalone\nlda #0; cmp X to make a carry (equality's Z isn't rotatable), paying for a non-fused compare\nPLUS the value computation while saving only ~6 B on the materialize. A hand-built CmpSel\npseudo hits the same two costs, so it was not built — the G_UADDE proxy + mechanism settle it.\n\nAlso confirmed read-only that UGE-as-value (b = a >= c) likewise diamonds — no branchless\nflag->byte path exists anywhere in the backend.\n\nDocs: full-native-materialize plan §Phase 0 Option B rewritten predicted -> measured (table +\ndisasm + mechanism); Status line notes both options measured; new prove-option-b plan records\nthe experiment; TODO item (c) tightened. Worktree removed; main vendor/ + 0002 uncontaminated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
