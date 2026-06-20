| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/74f04f4) | #321 ordering-value branchless: 16-bit candidate A BUILT + measured -> WON'T-DO |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/ef21088) | #321 plan: add handoff-state to ordering-value-branchless plan |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/ac4a0c6) | #321 plan: bank ordering-as-value branchless win via 16-bit materialization |

<!--history-meta v1
74f04f4	author	Will Norris
74f04f4	added	77
74f04f4	deleted	18
74f04f4	files	1
74f04f4	body	The mode-matched 16-bit-rol hypothesis (lda #$0000; rol a at M16, staying inside\nthe sustained-16-bit run to dodge the sep churn that closed the 8-bit v1 form) was\nimplemented in full on wt/321-cmpval -- ROLAcc16 + LDAImm16 + G_CARRY_BOOL16 +\nselectCarryBool16 + a legalizeZExt rewrite of zext(16-bit-G_SBC carry) -- and\nmeasured against the diamond baseline.\n\nIt WINS in isolated leaves (uge_v 25->23, uge_arith 54->42) but REGRESSES every\nrealistic a16 program, harder than v1:\n  - a16cmpaudit: +654 B both-widths / +78 B even gated to s16-direct-only\n  - whole a16 corpus: +340 B, ZERO programs improve (a16scavnz +262 from one site)\n\nThree structural reasons the select-diamond is optimal, none fixable at legalize time:\n  1. the diamond folds predicate inversion for free (the rol needs an explicit eor);\n  2. the diamond's M8 materialization tail matches the ambient mode after most\n     boolean sites in loop code (the rol's M16 tail forces an extra sep);\n  3. the diamond keeps the 0/1 in X; the rol routes it through an Imag16 ZP slot\n     that cascades into spills under register pressure.\n\nCandidate B (ADCImm16) is strictly worse (3-byte adc vs 1-byte rol, same reasons)\n-> not built. The remaining lever is a mode-agnostic post-REPSEP pseudo (partial,\nuncertain upside; delicate REPSEP work) -> not pursued (rare shape, modest gain).\n\nThe ordering-as-value branchless materialization is now WON'T-DO in BOTH the 8-bit\n(v1) and 16-bit (candidate A) forms; the select-diamond is the measured optimum.\nRecorded, not deferred (close-net-negatives). No 0002 change ships -- docs only.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ef21088	author	Will Norris
ef21088	added	18
ef21088	deleted	0
ef21088	files	1
ef21088	body	Records what is done (v1 8-bit close-out on main), the wt/321-cmpval spike\nstate (revert v1, build 16-bit form), the investigated facts (selectAddE 8-bit\nassert, no ROLAcc16, G_UADDE maxScalar S8), and the entry point (Phase 0 gate).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ac4a0c6	author	Will Norris
ac4a0c6	added	104
ac4a0c6	deleted	0
ac4a0c6	files	1
ac4a0c6	body	The v1 8-bit adc-tail churned rep/sep in the common 16-bit-ambient case (closed\nnet-negative). Plan the RIGHT form: a 16-bit (mode-matched) materialization\n(ROLAcc16 lda #0; rol, or ADCImm16) that stays in the M16 run -> no churn -> banks\nthe win where a16 actually runs (mostly-16-bit). Also sharpen the modest-gains\nmemory: any gain is a PRIORITY, never go/no-go; if the naive impl regresses build\nthe clean form, dont shelve the gain (user 2026-06-21).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
