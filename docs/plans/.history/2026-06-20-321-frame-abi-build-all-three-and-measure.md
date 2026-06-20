| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/715668f) | #321 frame-ABI: finalize the study — CONFIRMED-shelved (NULL), measured |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/2feb53e) | #321 frame-ABI: mark A0 done in the plan (DP-collision avoidable; GO) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/d83dacf) | #321 frame-ABI: mark P0 done in the plan (byte-identical gate PASS) |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/5a33180) | #321 frame-ABI: Step 0 done — register wt/321-frame-abi + correct the worktree setup |
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/ad1d6d3) | #321 frame-ABI head-to-head: plan to build all three frames and measure |

<!--history-meta v1
715668f	author	Will Norris
715668f	added	42
715668f	deleted	9
715668f	files	1
715668f	body	The A0 census decisively settled the frame-ABI head-to-head without building\nA1-A4/B/M: 0/13 realistic functions can profit from (a) DP-window or (b)\nstack-relative, because llvm-mos keeps locals register-resident in __rc (frame/\nspill traffic ~0). The soft static stack (c) is retained by measurement.\n\nRecord the outcome across the docs:\n  - plan: status -> RESOLVED; collapse the un-built phases (P1/A1-A4/B/M) into a\n    NOT-BUILT row; add an Outcome section + the prepared (user-triggered) #321 CC\n    evidence paragraph.\n  - TODO: the frame-ABI bullet -> RESOLVED (NULL), with the small remaining work\n    (merge durable artifacts + tear down worktree; user-triggered upstream post).\n  - CC frame-decision record: SUPERSEDED note — the proxy shelving is now a\n    direct-measurement shelving for both (a) and (b).\n  - agent-handoff: wt/321-frame-abi -> RESOLVED.\n\nWorktree commits: P0 c2eaf61, A0 a73c564, census 9617b0f. The (a)/(b) compiler\ndiff (off-by-default features in the worktree's 0002) does NOT land — failed the\ngo/no-go bar; durable artifacts (frameabi_*) merge back to main.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
2feb53e	author	Will Norris
2feb53e	added	17
2feb53e	deleted	6
2feb53e	files	1
2feb53e	body	A0 (the make-or-break gate) PASSED on wt/321-frame-abi (a73c564): the\nhand-encoded proof ROM ran at D=$1000, accessed a frame local via DP and the\n__rc16 cell via absolute simultaneously, yielding corpus_result==0xBBAA on both\nMAME and bsnes-jg -- proving absolute addressing reaches __rc regardless of D,\nso a DP-window can coexist with the fixed-ZP imaginary registers.\n\nRecord the eligibility rule (non-reentrant, <=256B, no-ISR/FP, __rc re-emitted\nas absolute) and the cost model: DP-window saves -1B per spilled-local access\nbut taxes +1B per __rc access + ~6-8B prologue/epilogue, so it wins only for\nspill-heavy/temp-light functions -- a narrow class (expected NULL-ish), to be\nsettled in phase M. Feasibility bar cleared -> proceed to A1.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
