| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/5f239f3) | #321 docs: indir-dst copy fold WON'T-DO — corpus trigger check 0/6 progs 0 B pattern absent |

<!--history-meta v1
5f239f3	author	Will Norris
5f239f3	added	129
5f239f3	deleted	0
5f239f3	files	1
5f239f3	body	Step 0 from the handoff plan: compiled all 6 corpus programs (arith, arrays, control,\nfuncs, globals, structs) with +mos-a16 and checked for the blocking round-trip pattern\n(`sta (zp)` in 16-bit context / `__IMAG16` load-store fingerprint in indirect-store paths).\n\nResult: 0/6 programs, 0 B aggregate. No corpus program uses `volatile T *volatile p_var`\n(the shape that blocks the fold); the −13 B from natural 16-bit mode is already captured;\nthe ~4 B selector-reorder gain is not justified. WON'T-DO.\n\nChanges:\n- docs/plans/2026-06-18-321-indir-dst-copy-fold.md: Status → WON'T-DO + corpus evidence\n- docs/plans/2026-06-18-321-indir-dst-copy-fold-handoff.md: closed with corpus results\n- TODO.md: #321 native s16 memory-access follow-ups → Done (all sub-items closed)\n- docs/agent-handoff.md: indir-dst row → CLOSED WON'T-DO\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
