| Date | Change |
|------|--------|
| [2026-08-02](https://github.com/wbniv/llvm-mos-65816/commit/6249aae) | fix(mos-late-opt): lower every CmpZero, not just those before the block's first fold |

<!--history-meta v1
6249aae	author	Will Norris
6249aae	added	75
6249aae	deleted	0
6249aae	files	1
6249aae	body	lowerCmpZeros used the function's loop-carried `Changed` accumulator as its\nper-instruction "did this fold?" flag, so once any CmpZero in a block folded\ninto an earlier NZ producer, every CmpZero processed afterwards took the early\ncontinue and was never lowered. Nothing downstream lowers the pseudo: it is\nlegal MIR, so -verify-machineinstrs stays silent, and the asm printer emits\nNOTHING for it -- the promised flag test disappears without a diagnostic.\n\nReproduces on PRISTINE upstream (build/upstream-llc) from 4 lines of MIR, no\nfork feature involved, so it is carried as standalone upstream-bound patch\n0022 (0003's slot lifecycle: wired into dev/toolchain.sh after 0003, baked\ninto dev/regen-patch.sh's BASELINE_MOSDIR so a 0002 regen cannot absorb it).\n\nFix: per-CmpZero `Folded` flag; also set `Changed` on the allDefsAreDead()\nerase path, which mutated the function while reporting no change.\n\nRed/green: new llvm/test/CodeGen/MOS/late-opt-cmpzero-after-fold.mir (pseudo\nsurvives before, lowered after, CHECK-NOT: CmpZero). MOS suite 83 tests with\nexactly the 7 pre-existing fork-divergence failures. Measured incidence in\nthis tree: ZERO -- 140 files x 4 configs, 17,403 blocks, max 1 CmpZero per\nblock -- so the fix is inert here; the value is upstream, where the failure\nmode is silent. Upstream PR package drafted (status row 18); posting is\nuser-triggered.\n\nForeign 0018/0019 hunk in dev/toolchain.sh left unstaged (another session's).\nSNESDQ_SKIP=1: whole-tree gate trips on another worker's video_hud.h.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
