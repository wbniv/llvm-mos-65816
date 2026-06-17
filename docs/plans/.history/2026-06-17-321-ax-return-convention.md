| Date | Change |
|------|--------|
| [2026-06-17](https://github.com/wbniv/llvm-mos-65816/commit/7ee904f) | #321 docs: calling-convention decision analysis + plan to lock the A/X return convention |

<!--history-meta v1
7ee904f	author	Will Norris
7ee904f	added	77
7ee904f	deleted	0
7ee904f	files	1
7ee904f	body	The ROADMAP flags the calling-convention decision as "open, blocks the ABI". Work it\nthrough and land the one free piece.\n\n- docs/investigations/65816-calling-convention-decision.md: the analysis/decision-framing\n  layer over the prior-art facts (docs/320-321-65816-c-abi-prior-art.md). The "one\n  decision" decomposes into 4 sub-decisions; only the frame (TCD DP-window vs stack-\n  relative vs keep the soft static stack) is hard. Key reframe: llvm-mos's imaginary\n  registers are already a global direct-page window, so the TCD per-frame window is\n  evolution, not a rip-out. The decision doesn't block xy16+crt0; upstream won't bless an\n  ABI ahead of an implementation. Recommendation: phase it (cheap path now, defer the\n  frame fork to post-xy16 measurement, never remove the soft static stack).\n- docs/plans/2026-06-17-321-ax-return-convention.md: plan for the trivial/free piece —\n  A (low) / X (high) return. VERIFIED it's already what llvm-mos emits (i8->A,\n  i16->A:X) but emergent from CC_MOS byte-splitting, untested + undocumented. Lock it as\n  a deliberate, differential-regression-guarded ABI invariant (codegen unchanged); the\n  +mos-a16 round-trip optimization + the 16-bit-register return are explicit follow-ups.\n- TODO.md M2: new calling-convention-decision item pointing at both.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
