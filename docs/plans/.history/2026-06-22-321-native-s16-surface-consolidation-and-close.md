| Date | Change |
|------|--------|
| [2026-06-22](https://github.com/wbniv/llvm-mos-65816/commit/95d65df) | #321 native-s16: plan the surface consolidation & close-out |

<!--history-meta v1
95d65df	author	Will Norris
95d65df	added	348
95d65df	deleted	0
95d65df	files	1
95d65df	body	Roll up the three open M2 native-s16 tracks (16-bit compares/branches,\nA16-threading, ALU-chain extensions) into one measure-and-close plan, the\n#321 analogue of the #320 zero-bank close. All three are already at their\nmeasured state (compares CLOSED; threading Phases 0/1/1.5 done + Phase 3\ndeferred; ALU-chains shipped + multi-value pressure characterized-deferred),\nso the deliverable is a durable surface map: a dev/measure-native-s16-surface.sh\nroll-up over the three existing harnesses + the missing ROADMAP step-5\nacceptance table, the recorded verdict, and the upstream "stage-1 native-s16\nmeasured-complete" paragraph.\n\nThe plan's one contribution: A16-threading Phase 3 and the >14-live ALU-chain\nresidual are the SAME deferred core (RA-level 16-bit residency under register\npressure, the globals.c -Os RA-crash class) -> one frontier, one trigger, one\nB0->B1->B2 spike recipe. Host-only measurement, no vendor/ change expected.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
