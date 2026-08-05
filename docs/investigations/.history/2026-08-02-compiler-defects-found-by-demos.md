| Date | Change |
|------|--------|
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/c9d81f3) | docs: consolidate the compiler defects the demo battery has exposed; record Apollo ROM progress |

<!--history-meta v1
c9d81f3	author	Will Norris
c9d81f3	added	60
c9d81f3	deleted	0
c9d81f3	files	1
c9d81f3	body	The battery's whole purpose is finding compiler bugs, but the record of what\nit has actually found was scattered across per-round blockquotes in the ideas\ndoc and the upstream paperwork ledger. This adds the index that ties a DEMO to\na DEFECT: 17 entries with class and disposition, the two loud scares that were\ncorrectly refuted rather than filed, and the pattern worth acting on -- four of\nthese were invisible to a passing gate (legal-but-wrong MIR has no diagnostic;\nseqvm's gate never ran -verify; the canary's entropy check had a stale binary\nto compare against).\n\nApollo plan: gate green, publication held on the black-dominant-picture doubt\nthe implementer raised -- proving the frames are real video before shipping.\n\nSNESDQ_SKIP=1: the gate trips on examples/snes/apollo-reel.c, the concurrently\nrunning agent's uncommitted file. Its PPU sites get reviewed and registered\nwhen that agent commits -- not stashed out from under it.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
