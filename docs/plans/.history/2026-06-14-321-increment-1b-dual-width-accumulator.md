| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/a6123d1) | #321 Inc 1b COMPLETE: a running 16-bit ADD through the dual-width A16 accumulator |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/6736297) | #321 Inc 1b step 1: model the dual-width 16-bit accumulator register |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/d34a89d) | #321 Inc 1b: plan + grounding investigation (cheap-fusion well is dry) |

<!--history-meta v1
a6123d1	author	Will Norris
a6123d1	added	97
a6123d1	deleted	17
a6123d1	files	1
a6123d1	body	g16 = a16v + b16v (0x1234 + 0x1111) now compiles under +mos-a16 to a\nsingle 16-bit-accumulator add — clc; rep #$20; lda; adc; sta; sep #$20 —\nand reads corpus_result == 0x2345 on BOTH MAME and bsnes-jg, driven\nsolely by the native-mode crt0. The real 16-bit value flows through the\nmodeled A16 = B:A accumulator: the genuine hard core of #321.\n\nHow it's built (all in patch 0002, mirroring #320's far-pointer style):\n- A16/B/Ac16 registers (step 1, already landed) added to AnyRegBank; a\n  HasAccum16 tablegen predicate; MLow TSFlag on MOSLogicalInstr + three\n  16-bit logical ops LDAbs16/ADCAbs16/STAbs16 (PseudoInstExpansion to the\n  width-agnostic LDA/ADC/STA_Absolute).\n- A pre-legalizer combiner rule fuses G_STORE(G_ADD(G_LOAD a, G_LOAD b),\n  g) -> a G_ADD16_ABS op; selectAdd16Abs lowers it to clc/lda/adc/sta on\n  Ac16 vregs; the existing MOSInsertREPSEP mode-walk brackets the run.\n\nFindings: (1) a legalizer rule for a MOS-specific *generic* opcode\ncorrupts the legalizer tables (heap bad-free at teardown — crashed the\nSDK's LTO link of crt0); G_ADD16_ABS is skipped by opcode-range, so it\nneeds no rule. (2) the clc must sit outside the REP/SEP run, else the\nmode-walk splits the bracket.\n\nNon-breaking: corpus 7/7, Inc 1a (0x0042) and far xcheck green, SDK\nbuilds. 31 B vs 48 B for the 8-bit carry chain (ROADMAP step 5's\nsmaller/faster). New dev/run.sh a16add + examples/65816/a16add.c.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
