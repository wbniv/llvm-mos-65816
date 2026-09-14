| Date | Change |
|------|--------|
| [2026-09-15](https://github.com/wbniv/llvm-mos-65816/commit/7899355) | fix(legalizer): notify the observer when rewriting indexed-offset uses (build determinism) |
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/f2ba409) | docs(nondeterminism): Phase 0 merged; retarget Phase 1 at sec placement, not ZP allocation |
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/3d4c67a) | Phase 0: reproduce build nondeterminism in all load arms; pin it to sec placement in _title_blank |
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/5f72591) | docs: plan to investigate a single unreproduced build-nondeterminism sighting |

<!--history-meta v1
7899355	author	Will Norris
7899355	added	251
7899355	deleted	8
7899355	files	1
7899355	body	Phase 1 of docs/plans/2026-09-14-eliminate-build-nondeterminism.md: the ~0.5 % `sec`\nplacement flip in `_title_blank` is a stale GlobalISel CSE node. The fork's\n`tryAbsoluteIndexedAddressing` (seed-56 known-bits block) rewrites every use of an\n8-active-bit s16 offset with a bare `MO.setReg()`, so `GISelCSEInfo` keeps the rewritten\n`G_TRUNC` under its old profile hash; the later `buildZExtOrTrunc` lookup in\n`selectIndirectAddressing` hits or misses depending on a bucket collision whose hash\nincludes the parent MBB pointer (ASLR). The one-vreg difference flips\n`TwoAddressInstructionPass`'s `SmallDenseMap<Register,...>` bucket order for the tied\n`SBCImag8` copies, which the scheduler keeps.\n\nFix: bracket each use rewrite with `changingInstr`/`changedInstr` (generic GISel's\nregister-replacement contract). Regression test `legalizer-indexed-offset-observer.mir`\n(REQUIRES: asserts): the rewritten s16 G_ADD survives under +mos-a16 and the\npost-legalizer mos-combiner's CSEInfo::verify() asserts pre-fix, passes post-fix.\nCarried in 0002 via regen-patch.sh TESTRELS. Not upstream-relevant (upstream uses\nbuildZExtOrTrunc there).\n\nVerified: measure-build-determinism --n 300 dither/newton/msquares 1 distinct each\n(was 2); corpus 63/63, corpus-a16 62/62; verify-machineinstrs sweep identical pre/post;\ncorpus ROMs 120/120 byte-identical; 114 demos differ only by carry-flag placement\n(fft/mulov64 main also re-legalized; both pass their differential gates).\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
f2ba409	author	Will Norris
f2ba409	added	61
f2ba409	deleted	48
f2ba409	files	1
f2ba409	body	Phase 0 (cherry-picked from throwaway/build-nondeterminism-phase0, a09bcb8)\nreproduced the flip in every arm -- quiet, Docker-loaded, generic-loaded --\nat ~0.5% per build on dither/newton/msquares over 2950 builds. The load\nhypothesis is ruled out; the earlier 68 quiet negatives were undersampled.\nThe bytes exonerate MOSZeroPageAlloc: ZP addresses are identical across\nvariants; only `sec` moves past carry-independent `tax`/`lda #imm` inside\n_title_blank. Semantically identical, so a reproducibility defect, not a\nmiscompile.\n\nPhase 1 rewritten around that: localise IR-pipeline vs codegen with a fixed\npost-LTO .bc, then first-divergent-pass via -print-after-all on flipping\nruns, then the pointer-ordered container in that pass. Load branch dropped.\nInbox entry updated to reflect a confirmed defect awaiting a Fable rank.\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa
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
