| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/4d8a2bd) | #321 xy16 Commit A: annotate X-governed transfers/push-pull in REPSEP requiredXWidth |

<!--history-meta v1
4d8a2bd	author	Will Norris
4d8a2bd	added	161
4d8a2bd	deleted	0
4d8a2bd	files	1
4d8a2bd	body	On the 65816 the transfer/push width of TAX/TAY/TXY/TYX and PHX/PLX/PHY/PLY is\ngoverned by the X flag, but requiredXWidth() treated the 8-bit-intent pseudos\n(TA, TX, PH/PL with $x/$y) as XW_None. When the cross-block dataflow holds X=16\nacross a loop back-edge, an 8-bit-intent TAY/TYX then runs 16-bit and drags the\nhidden B-accumulator high byte into Y.high/X.high → corrupt index/counter. (The\nM side never had this bug: requiredWidth defaults to MW_M8, so transfers were\nalready bracketed to M8; the X side defaulted to XW_None and slipped through.)\n\nFix: requiredXWidth returns XW_X8 for MOS::TA, MOS::TX (unconditional — 16-bit\ntransfers always use the dedicated TAX16/TAY16/TXA16/TYA16, XLow=1) and for\nMOS::PH/MOS::PL when operand 0 is $x/$y. T_A (TXA/TYA) is intentionally left\nX-agnostic (M-governed; its result A is X-independent). Monotone-conservative:\ncan only add a sep #$10, never remove one.\n\nVerified (fuzz 500, on the current bail toolchain): 491/500, NO PASS→FAIL flip,\nand a bonus — seed-157 (a +mos-xy16 mismatch on 8961afb) now PASSES: it was a\nsecond transfer-in-held-X16 bug, fixed here. seed-160 stays PASS. The lone\nremaining mismatch is seed-31 (critical-edge bug, fixed by Commit B). All 8\ncrashes are the pre-existing pre-REPSEP +mos-a16 $p-spill bug (169/173/196 +\nnewly-surfaced 268/271/272/306/420), provably independent of this post-RA change.\nCorpus 7/7, xy16 suite green; MIR spot-check confirms the sep fires before TX/TAY\nonly in X16 context (inert when X already 8); 0002 round-trips, foreign-hunks=5.\n\nThis unblocks re-landing the reverted B.begin() critical-edge fix (Commit B).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
