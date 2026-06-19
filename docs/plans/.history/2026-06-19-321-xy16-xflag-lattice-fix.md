| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/55ec505) | #321 xy16: fix the requiredXWidth index-width gap — clears all 5 remaining defects |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/b155b0d) | #321 xy16: add the X-flag lattice fix plan (the all-xy16 backlog) |

<!--history-meta v1
55ec505	author	Will Norris
55ec505	added	70
55ec505	deleted	10
55ec505	files	1
55ec505	body	MOSInsertREPSEP::requiredXWidth classifies each instruction's required X\n(index) width so the rep/sep dataflow can bracket it. Its switch enumerated\nthe index-register address/load/store/transfer ops that need X=8 but OMITTED\nthe index-register *value* ops: the compares CMPImm/CMPImag8/CMPAbs reading\nX/Y (-> cpx/cpy) and the register INC/DEC (-> inx/iny/dex/dey). These fell\nthrough to XW_None (X-agnostic), so each ran in whatever X width was AMBIENT.\n\nAfter a 16-bit-indexed load (rep #$30) the ambient is X=16, so `cpy #imm` read\na 2-byte immediate and compared the loop counter's UNINITIALIZED high byte\n(the counter was created/incremented at X=8) -> wrong loop bound -> infinite\nloop (corpus_result 0x0000) or wrong value. Root-caused via pr49419: MIR after\nmos-insert-rep-sep showed `CMPImm $y, 2` with only a `sep #$20` (M) restore\nbefore it, leaving X=16.\n\nFix: classify those ops XW_X8 when the compared/modified operand is X/Y\n(compares = operand 1; op0 is the Cc carry def. inc/dec = operand 0). The\naccumulator forms (CMP/CMPImm16, INA/DEA) keep XW_None. xy16-only by\nconstruction: requiredXWidth is only reached under HasIndex16, and the pass\nearly-returns unless hasAccum16() -> default and +mos-a16 codegen untouched.\n\nOne fix cleared the whole xy16 cluster (shared-cause hypothesis confirmed, as\nthe frame-index fix cleared 13): pr49419, doloop-1, 20041011-1, va-arg-22 (all\n4 xy16 c-torture xfails rows removed) + k_isort's xy16 leg. xfails.tsv now has\nno data rows -- every known #321 a16/xy16 c-torture miscompile is fixed.\n\nVerified: torture XPASS x4; k_isort 0xF47A all-agree (default==a16==xy16==host);\nfuzz 50: 45 PASS, 0 mismatch/0 crash + verify-machineinstrs clean; corpus 7/7;\n0002 regen round-trips, diff exclusively this hunk. Regression guard: the 4\nde-XFAIL'd torture rows + k_isort (always-on, exercises the xy16 leg).\n\nPlan: docs/plans/2026-06-19-321-xy16-xflag-lattice-fix.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
b155b0d	author	Will Norris
b155b0d	added	65
b155b0d	deleted	0
b155b0d	files	1
b155b0d	body	The high-leverage successor to the a16 frame-index fix: every remaining\n#321 c-torture/kernel failure is xy16 (16-bit index registers). Records\nthe X-flag-lattice hypothesis, the host-side reproduction, and the\nverification contract.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
