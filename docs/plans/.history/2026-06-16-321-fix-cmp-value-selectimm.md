| Date | Change |
|------|--------|
| [2026-06-16](https://github.com/wbniv/llvm-mos-65816/commit/56801ba) | docs: seed next pass — fix the cmp-value SelectImm crash (F3, 8 fuzz XFAILs) |

<!--history-meta v1
56801ba	author	Will Norris
56801ba	added	103
56801ba	deleted	0
56801ba	files	1
56801ba	body	Add docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md and wire it into the\nTier-1 plan, TODO item (c), and ROADMAP. Root-caused for the next pass: the\ns16 ORDERING native gate (MOSLegalizerInfo.cpp:1366, ICMP_UGE) lacks the\nall-uses-are-G_BRCOND_IMM guard the EQUALITY gate has (:1361), so an ordering\ncompare feeding a G_SELECT/PHI stays native and mis-materializes the C-flag i1\ninto SelectImm <GPR>. The conservative fix (narrow ordering-as-value to the\n8-bit chain) turns the 8 XFAIL seeds (1,7,9,11,22,35,41,44) green -> fuzz 50 1\n= 50/50. Repro: examples/65816/known/a16-cmp-value-selectimm.c.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
