| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/d18bbca) | #320 Inc 4 Ph2: implementation plan for far-ptr CC variants (b)/(c)/(d) + measurement |

<!--history-meta v1
d18bbca	author	Will Norris
d18bbca	added	129
d18bbca	deleted	0
d18bbca	files	1
d18bbca	body	Supplements the parent 2026-06-20 plan with the implementation-level mechanism found\nduring A0 + the A1 investigation: variants (b) Imag16+bank and (c) A:X+Y need a\nHETEROGENEOUS {i16 offset, i8 bank} register split, which the uniform\ngetNumRegistersForCallingConv mechanism can't express. The supported GISel path is\nassignCustomValue (CallLowering.h:310) + a CCCustom assigner — the ARM f64->2×GPR\nmodel, adapted with ptrtoint/trunc (out) and merge/inttoptr (in) for the\nheterogeneous pointer split. Built once for (b), reused by (c). (d) hw-stack is the\nuniform soft-stack path. Carries A0's decisions (Imag32-in-AnyRegBank, the stacked\n0004 patch home). Phased A1->A2->A3->M->D with the project differential bar.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01LNqksvWfK38piTuGXz8y5W
-->
