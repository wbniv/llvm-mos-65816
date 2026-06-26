| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/fc74388) | #321 a16 Phase-3 close-out artifacts (verdict + spike diff + measure trigger line) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/e7e2270) | #321 a16-threading Phase 3: plan the trigger-check pass (re-affirm or re-open) |

<!--history-meta v1
fc74388	author	Will Norris
fc74388	added	12
fc74388	deleted	1
fc74388	files	1
fc74388	body	Companion to the TODO.md close-out (landed via a concurrent commit on this hot\nshared tree). Records the trigger-check + pre-RA Ac16-residency spike that\nmeasured Phase 3 as net-negative (zero ZP-pressure relief, +24 B regression):\n - docs/investigations/2026-06-26-a16-phase3-prera-residency-spike.md (+ .diff)\n - dev/measure-zp-pressure.sh: explicit Phase-3 trigger (b) FIRE/defer line\n - plan: OUTCOME banner (trigger fired -> spike -> closed)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
e7e2270	author	Will Norris
e7e2270	added	193
e7e2270	deleted	0
e7e2270	files	1
e7e2270	body	Operationalizes the Watch re-open condition for the deferred RA-level Ac16\nresidency core. Plan: on a throwaway worktree, re-measure ZP pressure\n(trigger (b), ~10/14 Imag16 pairs) + run a large-N csmith crash-sweep\n(trigger (a), a new realistic regalloc-out-of-registers / zp-overflow);\nneither fires -> record dated evidence and stand pat; either fires -> run\nthe already-recorded B0->B1->B2 spike. No compiler change unless a trigger\nfires.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
