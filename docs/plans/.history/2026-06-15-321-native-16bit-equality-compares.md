| Date | Change |
|------|--------|
| [2026-06-15](https://github.com/wbniv/llvm-mos-65816/commit/acdba60) | #321 native s16: native 16-bit equality compares (== / !=) via fused compare-branch |

<!--history-meta v1
acdba60	author	Will Norris
acdba60	added	158
acdba60	deleted	0
acdba60	files	1
acdba60	body	An s16 `a == b` / `a != b` narrowed to a two-block 8-bit cmp/cpx chain; now each\n==/!= feeding a branch is one fused 16-bit compare-branch: rep; lda; cmp; sep;\nbeq/bne.\n\nUnlike the carry (unsigned-ordering) path, the Z flag can't be a plain i1 —\nselectSbc asserts "all N and Z uses must be selected to terminator instructions" —\nso equality must fuse into the branch. The pieces:\n\n- MOSLegalizerInfo.cpp: keep an s16 ICMP_EQ un-narrowed (a 16-bit G_SBC, Z output)\n  ONLY when every use of the result is G_BRCOND_IMM (so a stored-bool equality\n  stays 8-bit, avoiding the selectSbc N/Z assert). NE is canonicalized to EQ.\n- MOSInstrPseudos.td: CmpBrImag16 / CmpBrImm16 fused-compare-branch pseudos, Defs\n  [C, A16, NZ] (the expansion clobbers the accumulator and flags).\n- MOSInstructionSelector.cpp: type-discriminated CmpNZ16 matchers (+ an s8 guard on\n  the existing 8-bit CmpNZ_match so a 16-bit G_SBC never folds into an 8-bit\n  compare-branch); selectBrCondImm handles the s16 cases first.\n- MOSInstrInfo.cpp: expandCmpBr16 lowers post-RA to LDAImag16; CMPImag16/CMPImm16\n  (both MLow=1, so the late REP/SEP pass brackets lda;cmp) + BR reading Z. sep\n  doesn't touch Z, so the branch reads it correctly. Uses the physical A16 (the\n  pseudo's Defs cover it). getBranchDestBlock updated for the new pseudos.\n\na16eq reads 0x0011 (operands differ in both bytes, so a single-byte compare would\nmisfire), no 8-bit cpx/cpy chain; -verify-machineinstrs clean; both MAME + bsnes-jg.\nNon-breaking: corpus 7/7, all 18 a16* tests green, 0002 round-trips.\n\nFollow-ups: equality producing a stored bool (non-branch), signed ordering compares.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
