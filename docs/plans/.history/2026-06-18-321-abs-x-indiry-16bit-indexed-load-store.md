| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/940e26f) | #321 Increment 1e: native 16-bit abs,x and (zp),y indexed load/store |

<!--history-meta v1
940e26f	author	Will Norris
940e26f	added	418
940e26f	deleted	0
940e26f	files	1
940e26f	body	Adds two new 16-bit indexed load/store patterns to `legalizeLoadStore16`\nvia `tryIndexedAddressing16`:\n\n  G_PTR_ADD(global, G_ZEXT(idx8))  →  G_LOAD16_ABS_IDX   →  lda abs,x  (M=0)\n  G_PTR_ADD(zp_ptr, G_ZEXT(idx8)) →  G_LOAD16_INDIR_IDX →  lda (zp),y (M=0)\n\nBoth store variants (G_STORE16_ABS_IDX / G_STORE16_INDIR_IDX) follow the same\nlegalizer gate. One rep/sep bracket each (MLow=1 on the new LDAbsIdx16 /\nSTAbsIdx16 / LDIndirIdx16 / STIndirIdx16 MC pseudos). Saves ~3-7 B per\nindexed 16-bit load in byte-granularity array/buffer access vs the byte-pair\npath.\n\nNew files:\n  MOSInstrGISel.td      4 new G_{LOAD,STORE}16_{ABS,INDIR}_IDX pseudos\n  MOSInstrLogical.td    LDAbsIdx16, STAbsIdx16, LDIndirIdx16, STIndirIdx16\n  MOSLegalizerInfo.h/cpp  tryIndexedAddressing16 + call in legalizeLoadStore16\n  MOSInstructionSelector.cpp  selectMem16AbsIdx, selectMem16IndirIdx + wiring\n  examples/65816/a16absidx.c  corpus_result==0x9ABC (g_bytes[4] via abs,x)\n  examples/65816/a16indiry.c  corpus_result==0x5678 (g_pair.b via (zp),y)\n  dev/a16absidx.sh, dev/a16indiry.sh  end-to-end gate scripts\n\nVerified: disasm gate (opcode BF / B1 under rep), MAME + bsnes-jg both PASS,\nfuzz 50/50 (0 mismatch), -verify-machineinstrs clean, 0002 round-trips.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
