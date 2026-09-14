| Date | Change |
|------|--------|
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/3d4c67a) | Phase 0: reproduce build nondeterminism in all load arms; pin it to sec placement in _title_blank |
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/5f72591) | docs: plan to investigate a single unreproduced build-nondeterminism sighting |

<!--history-meta v1
3d4c67a	author	Will Norris
3d4c67a	added	120
3d4c67a	deleted	5
3d4c67a	files	1
3d4c67a	body	dev/measure-build-determinism.sh runs N full-driver builds per demo under quiet, Docker-loaded\nand generic-loaded arms, counts distinct ROM hashes, and keeps the reference plus every\ndivergent ROM. 2950 builds over three runs flipped 7 times — in every arm — so the flip is\nnot load-dependent. Each flipping demo has one recurring alternate output; the byte diff is\nthe original dither sighting exactly (offset 8029) and decodes to `sec` moving past\nindependent `tax`/`lda` before `sbc`, both sites inside _title_blank (title_layer.h). No\nzero-page assignment changes, so Phase 1 should target the scheduler / carry-set placement\nrather than MOSZeroPageAlloc.cpp. Plan updated with raw counts, indices and the disassembly.\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa\n(cherry picked from commit a09bcb8fd94d7d4241f034590978a7648886325e)
5f72591	author	Will Norris
5f72591	added	163
5f72591	deleted	0
5f72591	files	1
5f72591	body	One dither.c rebuild produced a different ROM during a batch of ~117 demo\nbuilds (byte 8029, a 4-byte rotation matching the #590 zero-page-tie-break\nsignature). 68 follow-up builds across 5 methodologies, all in a quiet\nwindow, came back identical -- not yet reproduced on demand. The quiet\nretest cannot distinguish "no bug" from "a contention-dependent bug that\nonly shows up under load": the original sighting happened while two\nsubagents were still running dev/run.sh gates (Docker-backed). Plan's\nPhase 0 tests a loaded arm against a quiet arm before any further\ndiagnosis, per the project's "every anomaly needs a concrete cause" rule.\n\nNot yet added to TODO.md: ranking a new item requires a Fable-orchestrated\nsession (this one is Sonnet 5); the rank-requires-fable hook blocks a\nnon-Fable session from adding a tier marker.\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
-->
