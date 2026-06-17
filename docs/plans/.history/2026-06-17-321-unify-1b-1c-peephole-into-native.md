| Date | Change |
|------|--------|
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/329fbff) | #321 plan: post-execution corrections to 1b/1c peephole retirement plan |
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/f390a78) | #321 retire 1b/1c GISel combiner peephole — native path covers all shapes |

<!--history-meta v1
329fbff	author	Will Norris
329fbff	added	87
329fbff	deleted	10
329fbff	files	1
329fbff	body	Seven accuracy fixes after critique:\n- "four files" → "six files" (MOSInstrLogical.td + MOSLegalizerInfo.cpp were also changed)\n- "Temporary regressions" section rewritten: A16-threading was already live at time of\n  implementation, so the anticipated +4-byte regressions never materialised\n- Step 1: fix a16ops.c → a16add.c (a16ops doesn't exist); note step was not run as written\n- Step 2: add MOSInstrLogical.td subsection; document selectAlu16AbsLd comment follow-on pass\n- Step 3: replace "all 10 a16* tests" overstatement with the five in-scope tests\n- Add "What actually landed where": bulk patch reduction (−1264 lines) is in fd304f6 (task7),\n  not f390a78 (retirement), due to shared vendor/ concurrent-regen; only 2 comment lines in f390a78\n- Add "Implementation traps": three anchor-consumed-content bugs (getImm16Operand comment,\n  selectGeneric signature, G_STORE_FAR_ABS island) with fixes, for future bulk-deletion reference\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f390a78	author	Will Norris
f390a78	added	318
f390a78	deleted	0
f390a78	files	1
f390a78	body	Delete the pre-legalizer GISel combiner peephole (7 rules, 14 pseudo-\ninstructions, ~6 selector functions, ~1400 lines across 5 files) that fused\n"all-global" s16 ALU shapes into target pseudos (G_ADD16_ABS, G_ADDCHAIN16_ABS,\netc.). The 1d-retry native path (selectAlu16Native + foldableAbsLoad16 +\nloadStoreValueIntoA16) already handles all these shapes correctly, making the\npeephole redundant.\n\nFiles changed: MOSCombine.td, MOSCombiner.cpp, MOSInstrGISel.td,\nMOSInstructionSelector.cpp, MOSLegalizerInfo.cpp (dead _ABSLD cases),\nMOSInstrLogical.td (stale comments).\n\nVerification: corpus 7/7 PASS, a16add/a16bit/a16chain/a16local/a16localx all\nPASS on MAME + bsnes-jg, -verify-machineinstrs clean, zero orphaned symbols.\na16chain byte size unchanged (3-op chain stays in one rep/sep bracket).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
