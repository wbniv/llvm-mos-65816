| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/9f3d71e) | feat(snes): #18 Maze generate + solve — recursion + A* priority-queue heap demo |

<!--history-meta v1
9f3d71e	author	Will Norris
9f3d71e	added	193
9f3d71e	deleted	0
9f3d71e	files	1
9f3d71e	body	Demo #18 of the compiler stress-test battery: the recursion + data-structure\nmember (multiply/divide-free, a different codegen profile from the mul/div\ndemos). Shared examples/65816/maze.h (host-portable) drives the host oracle,\nthe corpus slice, and the on-console ROM.\n\nGENERATE: recursive-division carve — genuine recursion (the soft-stack frame\nABI + JSR/RTS codegen), centre-biased so depth is ~log (≤16 for 16×15). A\nrecursive-backtracker DFS is infeasible here: 65816 JSR return addresses live\non the 256-byte hardware stack and llvm-mos keeps ~4 callee-saved bytes across\nthe self-call (~6 B/level), so a DFS's O(N) depth (≈190) silently overflows and\ncorrupts memory (first seen as three different stable-wrong CRCs).\n\nSOLVE: A* shortest path with an indexed binary min-heap (decrease-key via an\nhpos[] position map) + Manhattan heuristic — the heap sift-up/down + parallel-\narray + pos-map stress; split into init/step so the ROM animates one expansion\nper frame (explored cells dim, then the shortest path lights up).\n\nGate maze_gate_crc = 0x0749 (seed 0xC0DE). No far pointers ⇒ full 5-way bar.\nVerified: dev/run.sh maze RESULT PASS (disasm recursion(maze_divide self-call)=3\n+ rep/sep=227, zero 32-bit libcalls; bsnes-jg host==default==+mos-a16==+mos-xy16\n== 0x0749; -verify-machineinstrs clean all three; UBSan clean). On-screen A*\nreads back the exact host expanded=112/path_len=37. MAME leg pending the SPC700\nIPL (bsnes-jg + browser carry the demo bar).\n\nSurfaced a 65816 GISel mis-schedule ("defs don't dominate all uses" on a\nG_MERGE_VALUES, all builds) on a fold-while-walking loop — worked around by\nsplitting reconstruct/fold into two passes; upstream-worthy (noted in plan).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
