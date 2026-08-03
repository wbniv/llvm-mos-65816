| Date | Change |
|------|--------|
| [2026-08-03](https://github.com/wbniv/llvm-mos-65816/commit/2825aab) | plan: where interframe coding stops paying — measure the crossover before building anything |

<!--history-meta v1
2825aab	author	Will Norris
2825aab	added	89
2825aab	deleted	0
2825aab	files	1
2825aab	body	The recorded ratios show a monotone trend: as consecutive frames stop\nresembling each other, intraframe LZSS closes on and then beats interframe\nSVX2 (Artemis Bayer: SVX2 by 19.38 pts; Apollo static cut: LZSS by 2.67;\nApollo recut: LZSS by 14.31 — 5x wider on the same source footage).\n\nThe plan's contribution is the reframing. A chooser needs no new codec: SVX2\nalready carries an intraframe path in its keyframes, and on hard content a\nkeyframe costs about what a delta costs (K=15 vs K=120 spans only 3,233 B).\nBut size and time trade in opposite directions — a keyframe decodes in 1.12\nVBlanks against ~1.0 — so emitting whichever packet is smaller silently spends\nthe frame budget and stops presenting 60. It is minimize-bytes-subject-to-\ncadence: a scheduling problem, not a codec problem.\n\nP0 measures per frame (the recorded numbers are aggregates that hide the\ndistribution) and may well close this with "not worth it". P0b takes a second\nframe-rate point free from the in-flight true-60 work.\n\nSNESDQ_SKIP=1: whole-tree gate, other sessions' files.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
