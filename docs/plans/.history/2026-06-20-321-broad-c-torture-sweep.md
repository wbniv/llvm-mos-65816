| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/364de87) | #321 c-torture -Os sweep + load-fold fix: record results (1114 PASS, 0 FAIL) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/455df83) | #321 c-torture broad sweep: plan + TODO update for the -Os full execution |

<!--history-meta v1
364de87	author	Will Norris
364de87	added	13
364de87	deleted	6
364de87	files	1
364de87	body	Final verification of the -Os sweep and the load-fold-across-call fix:\n- full -Os re-sweep 1114 PASS, 0 FAIL, 54 SKIP (was 1112/2); pr34768-1/-2 PASS\n- fuzz 45/50, 0 mismatch / 0 crash\n- folds preserved (no win lost); verify-machineinstrs clean\n\nMarks the suite's -Os pass DONE in the [wip] c-torture item, adds the fix Done\nentry, and records the sweep + fix plan verdicts.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
455df83	author	Will Norris
455df83	added	88
455df83	deleted	0
455df83	files	1
455df83	body	Plan-first contract for the in-progress -Os sweep of the in-scope c-torture\nexecute set (the remaining pass of the [wip] suite item). Bug-finding run:\nMAME 3-way catch-net (default==a16==xy16), per-FAIL bsnes-jg confirmation,\nroot-cause + de-XFAIL + micro-test on any miscompile; also confirms the\njust-landed CMPIndir16 fold (9009260) is non-regressing.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
