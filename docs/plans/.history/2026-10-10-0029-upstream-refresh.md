| Date | Change |
|------|--------|
| [2026-10-10](https://github.com/wbniv/llvm-mos-65816/commit/95d122f1) | Refresh 0029 standalone validation and require dashboard publication |

<!--history-meta v1
95d122f1	author	Will Norris
95d122f1	added	23
95d122f1	deleted	0
95d122f1	files	1
95d122f1	body	Reconcile the existing register-exhaustion guard with upstream 0f031168a7cc and retain matching-input IR/MIR failures before the fix and passing results afterward. Refresh the standalone branch's MIR coverage for the LiveIntervals-only entry contract; allocate its rescheduled output. Complete MOS CodeGen/MC validation passes 140 tests with one unsupported. Migrate the original September report into its first canonical defect record without rewriting earlier evidence or review credits.\n\nThe original C passes all 24 full-driver and 24 candidate-backend checks on mos6502/mosw65816 at O0/O1/O2/O3/Os/Oz, with and without the verifier. The preserved unpatched backend fails all 20 optimized runs on identical emitted IR and passes four O0 runs. This shares the unchanged candidate frontend rather than claiming a separate pristine baseline Clang rebuild. Tracking, draft and preview distinguish completed validation from preview approval and the unposted PR. Preserve dated cross-target and runtime results. Allow current review/validation panels in the shared preview renderer and link the published discovery demo.\n\nRecord Will's standing instruction in AGENTS, the publication workflow and at the top of both upstream trackers: push documentation, publish wald3n.com/open-source, and verify the live view in the same update. Reviewed dependent summaries and regenerated their views and receipts.\n\nAssisted-by: OpenAI Codex CLI 0.162.0, model gpt-6.1-sol, medium reasoning effort; verified session 01a1208b-91e0-7e33-b5bf-8787d2a9c919
-->
