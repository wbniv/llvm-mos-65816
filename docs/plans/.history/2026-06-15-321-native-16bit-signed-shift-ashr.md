| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/915355b) | #321 native s16: native 16-bit signed right shift (arithmetic >>, cmp #$8000; ror) |

<!--history-meta v1
915355b	author	Will Norris
915355b	added	138
915355b	deleted	0
915355b	files	1
915355b	body	Completes the constant-shift family (the prior commit did << and unsigned >>). The\n65816 has no native arithmetic-shift-right, but in 16-bit-accumulator mode the\nper-bit idiom is two ops: `cmp #$8000` sets carry C = (A >= 0x8000) = the sign bit,\nthen `ror a` rotates that carry back into bit 15 while shifting right, so the sign\nreplicates. Repeating `cmp #$8000; ror a` k times is a correct k-bit arithmetic\nright shift, all in one rep/sep bracket.\n\n- MOSInstrLogical.td: RORAcc16 — a carry-threaded MLow=1 rotate (real carry-in from\n  the cmp; carry-out dead) expanding onto ROR_Accumulator (0x6A).\n- MOSLegalizerInfo.cpp: add G_ASHR to the native [1,7] shift passthrough.\n- MOSInstructionSelector.cpp: dispatch s16 G_ASHR to selectShift16Native, whose new\n  ASHR arm emits k x { CMPImm16 #$8000 -> Cc; RORAcc16 (Cc-in) }.\n\nCMPImm16 already existed (selectSbc16 uses it); the value never leaves Ac16 except\nvia LDAImag16/STAImag16 (no Ac16<->8-bit COPY). a16ashift sign-extends 0xF000 >> 3\n= 0xFE00 (reads 0xFE01) under one rep/sep, no lsr/ror byte chain, no libcall; both\nMAME + bsnes-jg. Non-breaking: corpus 7/7, all 17 a16* tests green, 0002 round-trips.\n\nFollow-ups: variable shifts, amount >=8, 1-byte inc a/dec a, memory-RMW inc abs.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
