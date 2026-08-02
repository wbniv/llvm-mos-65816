| Date | Change |
|------|--------|
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/c9d81f3) | docs: consolidate the compiler defects the demo battery has exposed; record Apollo ROM progress |
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/8828247) | plan+todo: Apollo 11 daylight video cartridge — turn the hard-content stressor into a ROM (wip T3) |

<!--history-meta v1
c9d81f3	author	Will Norris
c9d81f3	added	20
c9d81f3	deleted	1
c9d81f3	files	1
c9d81f3	body	The battery's whole purpose is finding compiler bugs, but the record of what\nit has actually found was scattered across per-round blockquotes in the ideas\ndoc and the upstream paperwork ledger. This adds the index that ties a DEMO to\na DEFECT: 17 entries with class and disposition, the two loud scares that were\ncorrectly refuted rather than filed, and the pattern worth acting on -- four of\nthese were invisible to a passing gate (legal-but-wrong MIR has no diagnostic;\nseqvm's gate never ran -verify; the canary's entropy check had a stale binary\nto compare against).\n\nApollo plan: gate green, publication held on the black-dominant-picture doubt\nthe implementer raised -- proving the frames are real video before shipping.\n\nSNESDQ_SKIP=1: the gate trips on examples/snes/apollo-reel.c, the concurrently\nrunning agent's uncommitted file. Its PPU sites get reviewed and registered\nwhen that agent commits -- not stashed out from under it.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8828247	author	Will Norris
8828247	added	73
8828247	deleted	0
8828247	files	1
8828247	body	The published reel plays Artemis (night launch, mostly-black frames whose\nnoise H.264 already smoothed). Apollo 11 is the deliberate opposite and was\npicked as the codec's worst realistic case: 16 mm daylight film, heavy grain,\n+5.3 ratio points under Floyd and +19.8 under Bayer. The ROM exists to\nproduce the cadence measurement on that input, next to the Artemis numbers.\n\nCorpus, packed streams and provenance already exist from the 2026-08-01\nstressor sweep; this is a sibling to snes-video-reel.c (which stays\nuntouched), not a second video pipeline.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
