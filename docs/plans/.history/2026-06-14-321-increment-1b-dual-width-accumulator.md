| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/6736297) | #321 Inc 1b step 1: model the dual-width 16-bit accumulator register |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/d34a89d) | #321 Inc 1b: plan + grounding investigation (cheap-fusion well is dry) |

<!--history-meta v1
6736297	author	Will Norris
6736297	added	11
6736297	deleted	5
6736297	files	1
6736297	body	Add the 65816's 16-bit accumulator to the MOS backend as A16 = B:A: a new\nhigh-byte register B (the accumulator's hidden high byte, swapped via XBA)\nand A16 aliasing A as its low sub-register, plus the single-member class\nAc16 (parallel to the 8-bit Ac). A16 aliasing A lets the register\nallocator know a 16-bit accumulator op clobbers A.\n\nNamed A16, deliberately NOT the WDC name "C": `def C` is the carry flag\n(register 7, a subreg of P), and conflating the 16-bit accumulator with\ncarry is a classic 65816 footgun — flagged in a comment at the definition.\n\nNon-breaking: the register is inert (nothing selects it until the\nlegalizer/selector steps land). Toolchain rebuilds clean, corpus 7/7.\nTracked in patches/llvm-mos/0002-321-accum16.patch. Step 1 of 5 in the\nInc 1b plan (Option A: full register modeling, first target the 16-bit add).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d34a89d	author	Will Norris
d34a89d	added	137
d34a89d	deleted	0
d34a89d	files	1
d34a89d	body	Start Increment 1b. Grounding investigation (five uint16_t kernels, 8-bit\nlowering dumped) shows the natural 16-bit cases route bytes through X/Y,\nnot A, so 1a's adjacent-STZ fusion has no analogue. A constant-store\npeephole is only break-even (the 4-byte REP/SEP bracket eats the one\nsaved op), failing ROADMAP step 5's smaller/faster bar. The first slice\nthat actually wins is the 16-bit add (~25->14 B), which requires modeling\na real dual-width accumulator register — the genuine hard core.\n\nThe MC layer is already in place (CC1_All auto-generates LDA/ADC\n_Immediate16 with MLow=1; absolute STA/LDA are M-governed), so the gap is\npurely GISel + register modeling. Plan captures the decomposition and the\nopen approach decision (full register modeling vs interim INC idiom);\nmark the TODO item [wip].\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
