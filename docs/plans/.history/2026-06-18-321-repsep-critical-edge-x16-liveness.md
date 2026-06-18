| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/8961afb) | #321 xy16 hang fix: XHigh on byte-level X/Y ops + requiredXWidth pseudo residency |

<!--history-meta v1
8961afb	author	Will Norris
8961afb	added	174
8961afb	deleted	0
8961afb	files	1
8961afb	body	Byte-level ldx/ldy/stx/sty were running in X16 mode (left set by a prior\nLDXImag16/LDXAbs16), so a 1-byte ldy/sty read/wrote 2 bytes and corrupted the\nadjacent ZP call-convention slot or struct byte — overflowing the soft stack and\nhanging (xy16@MAME=0x0000). 34/50 fuzz seeds hit this.\n\nTwo-part fix:\n  - XHigh=1 on the 14 real X/Y instruction defs (MOSInstrFormats.td CC0_Regular\n    _ZeroPage/_Absolute → LDY/CPY/CPX; MOSInstrInfo.td → 12 LDX/STX/LDY/STY\n    forms). requiredXWidth() already maps XHigh → XW_X8, so the REPSEP X-lattice\n    inserts sep #$10 before them.\n  - requiredXWidth() register-residency for the generic load/store pseudos that\n    only become LDX_ZeroPage/etc. at MC-lowering (AFTER REPSEP), so they carry no\n    XHigh TSFlag at REPSEP time: LDAbs/LDImag8/LDImm/STAbs (operand 0), STImag8\n    (operand 1), LDXIdx/LDYIdx (always X/Y) with $x/$y → XW_X8. Conservative: can\n    only add a sep, never remove one — a misclass misses a churn-min, never\n    regresses.\n\nFuzz 16/50 → 49/50, all 34 hangs cleared (0 new-crash). Corpus 7/7, xy16 suite\n(basic/spill/spillr/ops) green, seed-38 (documented post-mortem) → 0x2801 all\noracles agree. 0002 round-trips, foreign-hunk count unchanged (5).\n\nLone residual = seed-31, a pre-existing critical-edge X16-liveness mismatch (not\na hang) un-masked by this fix; tracked as a separate plan + open TODO item.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
