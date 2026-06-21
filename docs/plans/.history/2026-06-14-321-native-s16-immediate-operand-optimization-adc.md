| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/1628484) | #321 native s16: fold a constant operand into the immediate ALU form (adc #imm) |

<!--history-meta v1
1628484	author	Will Norris
1628484	added	143
1628484	deleted	0
1628484	files	1
1628484	body	selectAlu16Native now folds a compile-time-constant operand into the *Imm16 form\n(ADCImm16/ANDImm16/ORAImm16/EORImm16) instead of materializing the constant into\nan Imag16 pair: `t = a16v + 0x0345` (multi-use local) compiles to\n`clc; rep; lda a16v; adc #$0345; sta; sep` — dropping the ~4-instruction\n`ldx #lo; stx __rc; ldx #hi; stx __rc+1` materialization.\n\nA new getImm16Operand helper handles both shapes a 16-bit literal takes by\nselection time: a direct (look-through) constant, and — the common case — a\nG_MERGE_VALUES of two byte G_CONSTANTs (reconstructs lo|hi<<8). Commutative ops\n(add/and/or/xor) fold either operand via a swap; SUB never folds (no SBCImm16, and\n`x - C` is canonicalized to `x + (-C)` upstream). The now-dead constant def is\nremoved automatically by isTriviallyDead in the generic InstructionSelect pass —\nno manual erase. The accumulator invariant is unchanged (no Ac16<->8-bit COPY).\n\nTest a16localimm.c (multi-use local `a16v + 0x0345`) asserts adc-immediate\n(opcode 69, not 65 adc-zp), no materialization, corpus_result==0x1545 on both\nMAME and bsnes-jg; main drops to 19 instructions. Bitwise-immediate path probed\n(and #imm / ora #imm) — shares the code path.\n\nNon-breaking: corpus 7/7; all 11 a16* tests green; SDK builds; patch 0002\nround-trips (applies on 0001, reproduces vendor MOS dir exactly).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
