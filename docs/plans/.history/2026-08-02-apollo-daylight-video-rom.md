| Date | Change |
|------|--------|
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/8828247) | plan+todo: Apollo 11 daylight video cartridge — turn the hard-content stressor into a ROM (wip T3) |

<!--history-meta v1
8828247	author	Will Norris
8828247	added	73
8828247	deleted	0
8828247	files	1
8828247	body	The published reel plays Artemis (night launch, mostly-black frames whose\nnoise H.264 already smoothed). Apollo 11 is the deliberate opposite and was\npicked as the codec's worst realistic case: 16 mm daylight film, heavy grain,\n+5.3 ratio points under Floyd and +19.8 under Bayer. The ROM exists to\nproduce the cadence measurement on that input, next to the Artemis numbers.\n\nCorpus, packed streams and provenance already exist from the 2026-08-01\nstressor sweep; this is a sibling to snes-video-reel.c (which stays\nuntouched), not a second video pipeline.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
