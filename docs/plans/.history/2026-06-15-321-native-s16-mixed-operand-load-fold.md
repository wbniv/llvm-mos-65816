| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/75b395e) | #321 native s16: mixed-operand load-fold (t = a16v OP local, read the global directly) |

<!--history-meta v1
75b395e	author	Will Norris
75b395e	added	116
75b395e	deleted	0
75b395e	files	1
75b395e	body	A 16-bit ALU op with one near-abs global operand and one Imag16 register operand\n(a local / multi-use value) — the case neither both-global combiner (alu16_abs,\nalu16_absld) can reach — materialized the global into an Imag16 pair first\n(lda abs; sta tmp), then used it via the zp ALU form. selectAlu16Native now folds\nthe global directly at two independent sites: operand A into the LHS lda abs\n(LDAbs16), operand B into the absolute ALU form (adc/sbc/and/ora/eor abs).\n\nUniform across ADD/SUB/AND/OR/XOR and correct for both SUB directions with no\ncommutativity swap: the minuend is always operand A (loaded into A16), the\nsubtrahend operand B, and both fold sites preserve that order. Volatile-safe by\nthe same 1-to-1 single-use argument as the compare-operand fold (reuses the\nfoldableAbsLoad16 helper); folded loads are erased after constraining.\n\nNew test a16mixfold (ADD/SUB-both-ways/AND/OR/XOR mixing global a16v with multi-use\nlocal loc, corpus_result==0x2DC0): disasm gate asserts all 6 mixed ops read the\nglobal in place (lda abs / adc/sbc abs) with no Imag16 round-trip for it; MAME +\nbsnes-jg agree. a16localx's adc-zp gate updated to also count adc-abs (the fold\ncorrectly turns its t+c16v mixed add into adc abs). Full a16 suite (24 tests) +\ncorpus 7/7 green on both emulators; -verify-machineinstrs clean; patch 0002\nround-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
