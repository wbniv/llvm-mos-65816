| Date | Change |
|------|--------|
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/fd304f6) | #321 task7: CmpBrImagAbs16 — computed==global s16 EQ-as-value fold; items 2–7 deferred |

<!--history-meta v1
fd304f6	author	Will Norris
fd304f6	added	270
fd304f6	deleted	0
fd304f6	files	1
fd304f6	body	New pseudo `CmpBrImagAbs16` folds `(a+b) == g_global` to `lda zp_computed; cmp abs_global`\ninstead of materializing the global into Imag16 first. Both orderings supported via a new\nlegalizer `ComputedVsGlobal` gate + canonicalization swap (`isFoldableAbsS16Load(LHS) &&\nisImag16Resident(RHS)` → swap) + `GlobalVsImm` guard (`&& !isImag16Resident(LHS)`).\n\nSelector: `foldableAbsLoad16(RHS16)` inside the `m_CmpNZImag16` block emits `CmpBrImagAbs16`\nwith `.add(LdR->getOperand(1)).cloneMemRefs(*LdR)`; `expandCmpBr16` → `LDAImag16;CMPAbs16;BR`.\nDisasm gate uses `cf` (CMP Long 24-bit, SNES long addressing), not `cd` (CMP abs 16-bit).\nOnly in-block G_LOAD16_ABS folds safely; cross-block cases fall back to CmpBrImag16 (correct).\n\nVerification (MAME + bsnes-jg): `a16eqvalmg` corpus_result=0x0111 host==default==+mos-a16;\ndisasm: 2×`cf` in-block + 2×`c5` cross-block fallback; 0 cpx/cpy; -verify-machineinstrs clean.\nAll 6 equality micro-tests still pass. Patch: 7×CmpBrImagAbs16, no TXY/TYX leakage.\n\nSpike measurements for deferred items:\n- Item 2 (x==0 as value, a16eqvalz.c): +5 B (native rep/sep worse than 8-bit byte-OR) — DEFERRED\n- Item 3 (register/param EQ): +8 B (prior spike unchanged) — DEFERRED\n- Item 4 (blanket native EQ): regresses item 3 — DEFERRED\n- Item 5 (indir-dst, a16indirdst.c): −13 B (16-bit mode naturally wins; selector reorder\n  residual ~4 B but corpus gain unverified) — DEFERRED\n- Item 6 (X-flag/xy16): ABI breaks, no code-size benefit — DEFERRED\n- Item 7 (variable shifts): libcall wins at -Os — DEFERRED\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
