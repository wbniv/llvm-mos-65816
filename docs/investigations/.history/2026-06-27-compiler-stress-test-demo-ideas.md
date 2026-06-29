| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/9f3d71e) | feat(snes): #18 Maze generate + solve — recursion + A* priority-queue heap demo |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/572acf2) | docs(demo-ideas): strike through all completed demos + full-row for carry-chain |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/e66075e) | docs(ideas): add live links for Blossom + Space Invaders in preamble |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/7f860b3) | refactor(nbody→n-body): update all content refs after file rename |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/f9559f4) | docs(investigations): 20 compiler stress-test demo ideas (algorithm + visual) |

<!--history-meta v1
9f3d71e	author	Will Norris
9f3d71e	added	6
9f3d71e	deleted	4
9f3d71e	files	1
9f3d71e	body	Demo #18 of the compiler stress-test battery: the recursion + data-structure\nmember (multiply/divide-free, a different codegen profile from the mul/div\ndemos). Shared examples/65816/maze.h (host-portable) drives the host oracle,\nthe corpus slice, and the on-console ROM.\n\nGENERATE: recursive-division carve — genuine recursion (the soft-stack frame\nABI + JSR/RTS codegen), centre-biased so depth is ~log (≤16 for 16×15). A\nrecursive-backtracker DFS is infeasible here: 65816 JSR return addresses live\non the 256-byte hardware stack and llvm-mos keeps ~4 callee-saved bytes across\nthe self-call (~6 B/level), so a DFS's O(N) depth (≈190) silently overflows and\ncorrupts memory (first seen as three different stable-wrong CRCs).\n\nSOLVE: A* shortest path with an indexed binary min-heap (decrease-key via an\nhpos[] position map) + Manhattan heuristic — the heap sift-up/down + parallel-\narray + pos-map stress; split into init/step so the ROM animates one expansion\nper frame (explored cells dim, then the shortest path lights up).\n\nGate maze_gate_crc = 0x0749 (seed 0xC0DE). No far pointers ⇒ full 5-way bar.\nVerified: dev/run.sh maze RESULT PASS (disasm recursion(maze_divide self-call)=3\n+ rep/sep=227, zero 32-bit libcalls; bsnes-jg host==default==+mos-a16==+mos-xy16\n== 0x0749; -verify-machineinstrs clean all three; UBSan clean). On-screen A*\nreads back the exact host expanded=112/path_len=37. MAME leg pending the SPC700\nIPL (bsnes-jg + browser carry the demo bar).\n\nSurfaced a 65816 GISel mis-schedule ("defs don't dominate all uses" on a\nG_MERGE_VALUES, all builds) on a fold-while-walking loop — worked around by\nsplitting reconstruct/fold into two passes; upstream-worthy (noted in plan).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
572acf2	author	Will Norris
572acf2	added	19
572acf2	deleted	16
572acf2	files	1
572acf2	body	Mark #2, #8, #20 as done (missed in prior pass); strike their entries in the\nnumbered list, coverage map cells, and Recommended first picks. Strike the\nentire carry-chain row (label + numbers) since both #19 and #20 are now done.\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_013Zdsshyc1boVJkzfGNn4eC
e66075e	author	Will Norris
e66075e	added	2
e66075e	deleted	2
e66075e	files	1
e66075e	body	Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01KWxFJW6PaCDvq1FJE8Tuu6
7f860b3	author	Will Norris
7f860b3	added	13
7f860b3	deleted	13
7f860b3	files	1
7f860b3	body	Update internal file-path references, URLs, echo strings, includes,\nand docs throughout to match the nbody→n-body rename committed in 9369ced.\nAlso strikes through #13 N-body orbits in the demo ideas backlog\n(live at biohack.net/snes/n-body/).\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01KWxFJW6PaCDvq1FJE8Tuu6
f9559f4	author	Will Norris
f9559f4	added	111
f9559f4	deleted	0
f9559f4	files	1
f9559f4	body	Backlog of SNES 65816 demos that each lean on a different codegen corner (complex\nmul/div, recursion+soft stack, multi-precision carry chains, bit ops, shift-add,\nfar/high-WRAM, sin/cos LUTs) and render the computation itself. Grouped (fractals,\ncellular automata, trig/parametric, physics, discrete/big-int), with a codegen\ncoverage map and the shared-logic-header + differential-CRC + screenshot bar each\nshould meet. Complements the Mandelbrot/Blossom/Space-Invaders demos.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
