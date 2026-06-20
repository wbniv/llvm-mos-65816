| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/d83dacf) | #321 frame-ABI: mark P0 done in the plan (byte-identical gate PASS) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/5a33180) | #321 frame-ABI: Step 0 done — register wt/321-frame-abi + correct the worktree setup |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/ad1d6d3) | #321 frame-ABI head-to-head: plan to build all three frames and measure |

<!--history-meta v1
d83dacf	author	Will Norris
d83dacf	added	1
d83dacf	deleted	1
d83dacf	files	1
d83dacf	body	P0 (feature + frameStrategy() plumbing) is complete on wt/321-frame-abi\n(c2eaf61): off-by-default +mos-dp-frame/+mos-sr-frame + the tri-state query,\nproven byte-identical on the default + a16 corpus/kernels disasm (24/24). Record\nthe result and the refinement (branch-point switches deferred to A1/B with their\nlogic, rather than empty fall-through scaffolding).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
5a33180	author	Will Norris
5a33180	added	22
5a33180	deleted	18
5a33180	files	1
5a33180	body	Step 0 (feature worktree + warm toolchain + corpus sanity) is complete:\n  - wt/321-frame-abi created off main; vendor/llvm-mos + vendor/llvm-mos-sdk\n    real-copied (editable, carries 0002); build/ real-copied warm; bsnes-jg +\n    roms hardlinked.\n  - dev/run.sh toolchain: 34s incremental (clone skipped via copied .git;\n    "ninja: no work to do"), confirming the relocated build tree works under\n    the /work mount.\n  - dev/run.sh corpus: 7/7 PASS.\n\nRegister the worktree in the agent-handoff Active-worktrees table, and correct\nthe plan's Step 0 to the proven layout: the howto's cp -al hardlink shortcut is\nfor the NON-rebuild case; a compiler-changing feature must real-copy build/\n(warm ccache -> fast incremental) and keep vendor/llvm-mos/.git (else\ntoolchain.sh re-clones and wipes the tree; regen-patch also needs it).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
ad1d6d3	author	Will Norris
ad1d6d3	added	236
ad1d6d3	deleted	0
ad1d6d3	files	1
ad1d6d3	body	The xy16 hardware-stack ABI's blocking sub-decision (how to store\nlocals/frames) was settled on an INDIRECT proxy: the ZP-pressure\nmeasurement deferred (a) the TCD DP-window and ruled out (b) pure\nstack-relative on paper. Per lesson #1 (measure, don't assume), this plan\nbuilds all three frames to production quality -- (a) DP-window, (b) FULL\nstack-relative, (c) soft-static baseline -- behind off-by-default subtarget\nfeatures, and runs a three-way head-to-head on size + real MAME cycles +\nthe 4-way differential.\n\nSurfaces the load-bearing DP-collision (the SNES linker hard-fixes __rc* at\nZP $00-$1F and 65816 ZP addressing is DP-relative, so D!=0 retargets every\nlda __rcN -- the A0 make-or-break gate). Runs on a wt/321-frame-abi feature\nworktree with a pre-registered go/no-go; a null result is the expected,\nupstream-strengthening conclusion that feeds the user-triggered #321 CC\nposting.\n\nPlan + TODO M2 entry only; no vendor/ change yet.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
