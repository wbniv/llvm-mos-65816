| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/b8585db) | #321 native s16: lock in load-fold (b) — single-use-non-store results (regression guard) |

<!--history-meta v1
b8585db	author	Will Norris
b8585db	added	81
b8585db	deleted	0
b8585db	files	1
b8585db	body	Load-fold follow-up (b): a both-global 16-bit ALU op whose single-use result does\nNOT feed a near-abs store. matchAlu16AbsLd skips it (its `>1 use` guard targets\nmulti-use results) and matchAlu16Abs skips it (it needs a near-abs-store result),\nso before the mixed-operand fold both globals were materialized into Imag16 pairs.\n\nNo new codegen is needed: the mixed-operand fold (75b395e) generalized\nselectAlu16Native to fold any single-use near-abs G_LOAD16_ABS operand — keyed on\nthe operands, not on the result's use-count or consumer. So a single-use-non-store\nop reaches selectAlu16Native (neither combiner fires) and both globals fold there\n(`lda abs a; OP abs b`), identical to selectAlu16AbsLd's output. Verified across\nindirect-store-feeding, shift-feeding, and compare-feeding shapes — all fold, all\n-verify-machineinstrs clean.\n\nThis commit adds the missing regression guard: no existing test asserted the\nboth-global single-use-non-store shape on the emulators (a16loadfold's result is\nmulti-use; a16mixfold mixes one global + one local; a16localx uses Imag16-local\noperands). New a16sunfold (ADD/SUB/AND, each both-global single-use feeding a\nfurther non-store op, corpus_result==0x3480): disasm gate asserts 0 globals\nmaterialized into Imag16 pairs (9/9 operand reads direct) and the abs ALU forms\npresent; MAME + bsnes-jg agree. Full a16 suite (25 tests) + corpus 7/7 green;\npatch 0002 unchanged and round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
