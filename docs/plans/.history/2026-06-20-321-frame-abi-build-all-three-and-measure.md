| Date | Change |
|------|--------|
| [2026-06-20](https://github.com/wbniv/llvm-mos-65816/commit/ad1d6d3) | #321 frame-ABI head-to-head: plan to build all three frames and measure |

<!--history-meta v1
ad1d6d3	author	Will Norris
ad1d6d3	added	236
ad1d6d3	deleted	0
ad1d6d3	files	1
ad1d6d3	body	The xy16 hardware-stack ABI's blocking sub-decision (how to store\nlocals/frames) was settled on an INDIRECT proxy: the ZP-pressure\nmeasurement deferred (a) the TCD DP-window and ruled out (b) pure\nstack-relative on paper. Per lesson #1 (measure, don't assume), this plan\nbuilds all three frames to production quality -- (a) DP-window, (b) FULL\nstack-relative, (c) soft-static baseline -- behind off-by-default subtarget\nfeatures, and runs a three-way head-to-head on size + real MAME cycles +\nthe 4-way differential.\n\nSurfaces the load-bearing DP-collision (the SNES linker hard-fixes __rc* at\nZP $00-$1F and 65816 ZP addressing is DP-relative, so D!=0 retargets every\nlda __rcN -- the A0 make-or-break gate). Runs on a wt/321-frame-abi feature\nworktree with a pre-registered go/no-go; a null result is the expected,\nupstream-strengthening conclusion that feeds the user-triggered #321 CC\nposting.\n\nPlan + TODO M2 entry only; no vendor/ change yet.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
