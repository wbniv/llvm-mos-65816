| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/6f25977) | #321 Inc 1c: chained 16-bit ADD — a value stays live in A16 across ops |

<!--history-meta v1
6f25977	author	Will Norris
6f25977	added	119
6f25977	deleted	0
6f25977	files	1
6f25977	body	g = a + b + c now fuses under +mos-a16 to one REP/SEP bracket\n  rep #$20; lda b; clc; adc a; clc; adc c; sta g; sep #$20\nthreading the running sum through A16 — the intermediate (a+b) survives\nin the accumulator for the +c. Reads corpus_result == 0x1230 on BOTH\nMAME and bsnes-jg. This is the first codegen where a 16-bit value\nsurvives across operations in the register (not just within one fused\nop) — the first slice of the general path beyond 1b's fixed g = a OP b.\n\nHow: a pre-legalizer combiner rule (add_chain16) recursively walks the\nG_ADD tree (collectAddChain) gathering near-abs-global load terms, builds\na variadic G_ADDCHAIN16_ABS pseudo, and selectAddChain16 threads A16 down\nthe chain (lda t0; clc; adc t1; ...; sta g). Disjoint from 1b's alu16_abs\nby construction (fires only on >=3-term load chains; the clc carry-inits\nare M-agnostic so the whole chain stays in one bracket).\n\nNon-breaking: 1b add 0x2345 / sub 0x0123 / bitwise 0x0F00 / imm 0x1545,\n1a 0x0042, corpus 7/7, SDK builds. New dev/run.sh a16chain +\nexamples/65816/a16chain.c. Patch 0002 regenerated (round-trip verified).\nPlan: docs/plans/2026-06-14-321-increment-1c-chained-16bit-alu.md\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
