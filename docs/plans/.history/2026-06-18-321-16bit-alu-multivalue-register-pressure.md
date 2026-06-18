| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/97e58e4) | #321 plan: 16-bit ALU multi-value register pressure — measured characterization |

<!--history-meta v1
97e58e4	author	Will Norris
97e58e4	added	243
97e58e4	deleted	0
97e58e4	files	1
97e58e4	body	The TODO item "spilling when >1 16-bit value is live at once" rests on a\nmisleading premise. Measured on the built toolchain (clang-23, 2026-06-18):\n\n- There are ~14 sixteen-bit slots (the Imag16 pool), not one. Ac16 is the\n  transient accumulator; Imag16 (RS1-7, RS9-15) is the 16-bit register file.\n- 2-9 live s16 values already compile tight: distinct Imag16 pairs, ONE\n  rep/sep bracket, the 2nd live value folded as a memory operand (and/adc\n  __rcN). -58..-65% vs default 8-bit (p1 51 vs 147 B, p3 136 vs 334 B).\n- Correct even at pool exhaustion (-verify-machineinstrs clean, no crash) —\n  F3 / soft-stack / SPILL-CONTRACT already cover Imag16 spills.\n\nThe lone genuine residual: at >14 live s16 values the spills emit byte-wise\nthrough X in 8-bit mode (sep; ldx lo; stx slot; ldx hi; stx slot+1; rep),\nfragmenting the M=16 region into many brackets (13 on a 20-live probe). Real\nbut pathological-only — no kernel/corpus/fuzz program hits it.\n\nPlan gates any implementation on a Phase 0 trigger scan -> likely DEFER. A\nfully-specified, conservatively-gated MOSInsertREPSEP spill-fusion peephole\n(Phase 1) is ready if a trigger surfaces. Updated the TODO bullet to match.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
