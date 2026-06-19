| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/455df83) | #321 c-torture broad sweep: plan + TODO update for the -Os full execution |

<!--history-meta v1
455df83	author	Will Norris
455df83	added	88
455df83	deleted	0
455df83	files	1
455df83	body	Plan-first contract for the in-progress -Os sweep of the in-scope c-torture\nexecute set (the remaining pass of the [wip] suite item). Bug-finding run:\nMAME 3-way catch-net (default==a16==xy16), per-FAIL bsnes-jg confirmation,\nroot-cause + de-XFAIL + micro-test on any miscompile; also confirms the\njust-landed CMPIndir16 fold (9009260) is non-regressing.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
