| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/e7e2270) | #321 a16-threading Phase 3: plan the trigger-check pass (re-affirm or re-open) |

<!--history-meta v1
e7e2270	author	Will Norris
e7e2270	added	193
e7e2270	deleted	0
e7e2270	files	1
e7e2270	body	Operationalizes the Watch re-open condition for the deferred RA-level Ac16\nresidency core. Plan: on a throwaway worktree, re-measure ZP pressure\n(trigger (b), ~10/14 Imag16 pairs) + run a large-N csmith crash-sweep\n(trigger (a), a new realistic regalloc-out-of-registers / zp-overflow);\nneither fires -> record dated evidence and stand pat; either fires -> run\nthe already-recorded B0->B1->B2 spike. No compiler change unless a trigger\nfires.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
