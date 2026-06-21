| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/b5b2ddf) | #320 packed-24: record productionization follow-ups + next-batch handoff |

<!--history-meta v1
b5b2ddf	author	Will Norris
b5b2ddf	added	122
b5b2ddf	deleted	0
b5b2ddf	files	1
b5b2ddf	body	Increment B is done/verified/landed (0006, ebfc95e). Capture the remaining packed-24\nwork as a focused next batch + handoff:\n - (A) measure the win in REALISTIC 16-bit-ambient context — the -25% is a synthetic\n   16-entry-table number; lesson #2/#3 want a runtime-walked banked far-ptr table\n   measured net-of-access-cost, with a break-even table size.\n - (B) fix the confirmed byte-2 absolute-long access cost: a packed access stores/loads\n   bytes 0,1 via abs but byte 2 (the A-register byte) via 8f/af (R_MOS_ADDR24) even on a\n   near slot -> ~1 wasted byte per access site.\n - (C) stretch: an ergonomic __far_packed spelling.\nzero-bank (AS4) + the upstream-note posting stay separate threads.\n\nNew: docs/plans/2026-06-21-320-packed24-productionization-handoff.md (the resume\nprompt). Pointers added to the five-space plan's Increment-B section and the TODO item.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_016UaEGRGLhZFsejueUD9cnj
-->
