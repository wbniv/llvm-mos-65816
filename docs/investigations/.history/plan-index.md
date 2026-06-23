| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/0d76bfc) | #321 c-torture Phase 2 (-O1): 16 confirmed NEW a16/xy16 runtime miscompiles |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/f9a33d6) | #321 docs: reflect c-torture Phases 0+1 across the index docs |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/3be4584) | #321 docs: add the c-torture differential-suite plan to the plan index |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/8006801) | #321 docs: add plan index + deferred/rejected-items investigation tables |

<!--history-meta v1
0d76bfc	author	Will Norris
0d76bfc	added	1
0d76bfc	deleted	1
0d76bfc	files	1
0d76bfc	body	Full -O1 differential pass over all 1253 in-scope tests:\n1098 PASS, 136 SKIP, 3 known-XFAIL (a16-zp-pressure-overflow) + 16 FAIL.\n\nAll 16 FAILs re-run in isolation on a quiet box with bsnes-jg REPRODUCED\n(zero flakes); every a16 case agrees on both MAME and bsnes-jg. They are\nNEW runtime wrong-value miscompiles (default self-checks PASS, a16/xy16\nwrites 0xDEAD) — not the known register-pressure family — and diverse\n(packed structs, nested struct/arrays, memset, varargs, signed left-shift,\ncomputed-goto, counted loops at INT limits) => likely several distinct\na16/xy16 codegen bugs. This is the payoff of the external suite: real bugs\nthe home-grown tests never hit.\n\nRecorded in examples/65816/torture/xfails.tsv (expected-fail manifest);\ntorture_run.py now reports a listed test as XFAIL (and a fixed one as\nXPASS -> "remove the row"), so the gate is green-modulo-known. Per-defect\nroot-cause is the open backlog (new TODO item). No vendor/llvm-mos change.\n\nNote: the -Os pass didn't run (the runner left orphan MAME children that\nhung teardown after -O1, and set -e stopped the chained pass); the 16 are\nunaffected (confirmed isolated). -Os rerun + orphan-reaping are follow-ups.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f9a33d6	author	Will Norris
f9a33d6	added	1
f9a33d6	deleted	1
f9a33d6	files	1
f9a33d6	body	- plan-index.md: c-torture row -> Phases 0+1 done (pilot 102/17/1, the\n  pr15296 ZP-pressure finding); add the e9e3de6 + 15542ff commits.\n- deferred-and-rejected-items.md: note the a16-zp-pressure-overflow as a\n  sibling symptom on the globals.c XFAIL row (same Phase-3 fix).\n- agent-handoff.md: the emulator differential gate is live —\n  dev/run.sh torture, oracle-gated SKIP/FAIL/XFAIL.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3be4584	author	Will Norris
3be4584	added	1
3be4584	deleted	0
3be4584	files	1
3be4584	body	New row for 2026-06-19-321-c-torture-execute-differential-suite.md\n(Phase 0 landed). Index now covers all 74 plans.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8006801	author	Will Norris
8006801	added	102
8006801	deleted	0
8006801	files	1
8006801	body	Two new reading-map docs under docs/investigations/:\n\n- plan-index.md — every plan under docs/plans/ (73 rows), one per plan,\n  sorted oldest→newest by creation commit, with a one-line summary, the\n  git-log --follow commit set, and a category. The table of contents over\n  the M0→M1→M2 arc.\n\n- deferred-and-rejected-items.md — the negative-space companion: 19 paths\n  that were NOT carried to completion (DEFERRED / XFAIL / PARKED / REJECTED\n  / WON'T-DO / REVERTED), each with the reason, the revisit trigger, and the\n  disposition record. Leads with the live DEFERRED work, trails the settled\n  dead-ends. Sourced from plan status headers, TODO §Watch/§Parked, the\n  triaged Inbox deferral ledger, and in-plan Deferred/Out-of-scope sections.\n\nDocs-only; no vendor/ or 0002 change.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
