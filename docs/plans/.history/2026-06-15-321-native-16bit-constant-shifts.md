| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/01bde72) | #321 native s16: native 16-bit constant shifts (asl/lsr, no 8-bit byte-pair chain) |

<!--history-meta v1
01bde72	author	Will Norris
01bde72	added	192
01bde72	deleted	0
01bde72	files	1
01bde72	body	`x << k` / unsigned `x >> k` (k a compile-time constant) narrowed to the 8-bit\nasl/rol (or lsr/ror) byte-pair chain even under +mos-a16. In 16-bit-accumulator\nmode one `asl a` / `lsr a` shifts all 16 bits, so a small constant shift collapses\nto one `lda; (asl|lsr)*k; sta` run.\n\n- MOSInstrLogical.td: ASLAcc16 / LSRAcc16 — MLow=1 pseudos expanding onto the\n  zero-operand ASL_Accumulator (0x0A) / LSR_Accumulator (0x4A), Constraints\n  "$dst = $src", no carry operand (each shift self-fills 0).\n- MOSLegalizerInfo.cpp legalizeShiftRotate: after the Amt==0 base case, leave a\n  small s16 G_SHL/G_LSHR (amount in [1,7]) un-narrowed under hasAccum16 (mirrors\n  legalizeAddSub's native passthrough). Amount >=8 keeps the byte-relabel path;\n  G_ASHR (signed) stays on the byte path (a follow-up).\n- MOSInstructionSelector.cpp: dispatch s16 G_SHL/G_LSHR to new selectShift16Native,\n  which emits LDAImag16; k x (ASLAcc16|LSRAcc16) threading A16; STAImag16. The\n  value enters A16 only via the load and leaves via the store (no Ac16<->8-bit\n  COPY); the dead G_CONSTANT amount is erased by isTriviallyDead.\n\nMOSInsertREPSEP brackets the all-MLow=1 run automatically. a16shift reads 0x1278\nwith 4x asl + 2x lsr under one rep/sep (the mode tracker even folds a following\nadd into the same bracket), no rol/ror pairs, no __ashlhi3 libcall; both MAME +\nbsnes-jg. Non-breaking: corpus 7/7, all 16 a16* tests green, patch 0002 round-trips.\n\nFollow-ups: signed >> (ASHR), variable shifts, amount >=8 / xba, 1-byte inc a/dec a,\nmemory-RMW inc abs, shift-into-store fusion.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
