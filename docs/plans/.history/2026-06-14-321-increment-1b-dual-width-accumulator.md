| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/d34a89d) | #321 Inc 1b: plan + grounding investigation (cheap-fusion well is dry) |

<!--history-meta v1
d34a89d	author	Will Norris
d34a89d	added	137
d34a89d	deleted	0
d34a89d	files	1
d34a89d	body	Start Increment 1b. Grounding investigation (five uint16_t kernels, 8-bit\nlowering dumped) shows the natural 16-bit cases route bytes through X/Y,\nnot A, so 1a's adjacent-STZ fusion has no analogue. A constant-store\npeephole is only break-even (the 4-byte REP/SEP bracket eats the one\nsaved op), failing ROADMAP step 5's smaller/faster bar. The first slice\nthat actually wins is the 16-bit add (~25->14 B), which requires modeling\na real dual-width accumulator register — the genuine hard core.\n\nThe MC layer is already in place (CC1_All auto-generates LDA/ADC\n_Immediate16 with MLow=1; absolute STA/LDA are M-governed), so the gap is\npurely GISel + register modeling. Plan captures the decomposition and the\nopen approach decision (full register modeling vs interim INC idiom);\nmark the TODO item [wip].\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
