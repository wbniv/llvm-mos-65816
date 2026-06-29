| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/70e1840) | feat(snes): #9 Lissajous / Harmonograph — damped sin-LUT curve demo |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/30333e0) | feat(snes): #5 Conway's Game of Life — bit-parallel SWAR neighbour sums |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/5d7319a) | docs(demo-ideas): strike #12 CORDIC — published + live (biohack.net/snes/cordic/) |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/070328f) | feat(snes): #10 Fourier epicycles — many-multiply / sin-cos stress demo |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/f8aff1c) | feat(snes): #17 Sorting Race demo — quicksort/heapsort/mergesort recursion stress |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/32a4114) | feat(snes): #7 Doom-fire / heat-field demo — array sweep + PRNG, palette ramp |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/9f3d71e) | feat(snes): #18 Maze generate + solve — recursion + A* priority-queue heap demo |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/572acf2) | docs(demo-ideas): strike through all completed demos + full-row for carry-chain |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/e66075e) | docs(ideas): add live links for Blossom + Space Invaders in preamble |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/7f860b3) | refactor(nbody→n-body): update all content refs after file rename |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/f9559f4) | docs(investigations): 20 compiler stress-test demo ideas (algorithm + visual) |

<!--history-meta v1
70e1840	author	Will Norris
70e1840	added	4
70e1840	deleted	4
70e1840	files	1
70e1840	body	Demo #9 of the compiler stress-test battery — the damped sibling of the\n#11 spirograph (multiply-only). Four detuned pendulums (two per axis)\ntrace a Lissajous figure that precesses and spirals inward as an\nexponential envelope decays. Per sample the hot loop issues eight\n__mulsi3 — four amplitude products sin·env + four envelope-decay\nproducts env·decay (the running exponential env=(env·decay)>>15, a\nsustained fixed-point multiply + accumulation) — plus the Q8.8 sine LUT,\nwith NO divide. The envelope is scaled (ENVF=2) so env·decay fits int32.\nRendered into a BitmapCanvas with a 2-row HUD; four presets cycle as\neach figure settles.\n\nGate harmo_gate_crc = 0x0EBB (256 samples of preset 0, rotate-XOR fold\nof both coords). No far pointers ⇒ full 5-way bar. Verified:\ndev/run.sh harmonograph RESULT PASS (disasm __mulsi3=2 + rep/sep=36,\nzero divide; bsnes-jg host==+mos-a16 0x0EBB; -verify-machineinstrs clean\non default/+mos-a16/+mos-xy16; MAME pending the env-wide SPC700 IPL —\nnon-blocker per the demos-only policy). Published\nbiohack.net/snes/harmonograph/ (biohack.net v1.0.115).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
30333e0	author	Will Norris
30333e0	added	3
30333e0	deleted	3
30333e0	files	1
30333e0	body	Demo #5 of the compiler stress-test battery — the 2-D bit-manipulation\nmember (companion to the 1-D #6 Rule 90/110), deliberately multiply-/\ndivide-free. A 128×112 bit-packed grid (8 cells/byte) evolves by B3/S23:\neach byte's eight neighbour bit-vectors are summed bit-parallel into a\n4-bit-per-cell count via a ripple of SWAR half-adders (carry=a&b;\nsum=a^b) — pure and/eor/ora plus constant-1 asl/lsr for the cross-byte\nneighbour alignment, plus the two-buffer ping-pong swap. A Gosper glider\ngun fires gliders into a settling random soup, rendered on BG3 2bpp via a\ncustom LifeGrid drawable (doom-fire-style full-grid streaming, 56\ntiles/frame).\n\nGate life_gate_crc = 0xDDF1 (Gosper gun on 64×48 grid, 32 gens, CRC-16\nof all output rows). No far pointers ⇒ full 5-way bar. Verified:\ndev/run.sh life RESULT PASS (disasm shifts=22 bools=51, zero\n__mulsi3/__udivmodsi4; bsnes-jg host==+mos-a16 0xDDF1;\n-verify-machineinstrs clean on default/+mos-a16/+mos-xy16; MAME pending\nthe env-wide SPC700 IPL — non-blocker per the demos-only policy).\nPublished biohack.net/snes/life/ (biohack.net v1.0.114).\n\nFiles: examples/65816/life.h (logic), examples/snes/life.c (ROM),\nexamples/snes/corpus/life_sim.c (slice), tools/life-sim.c (oracle),\ndev/life.{sh,lua} (gate), plus Taskfile/TODO/plan/plan-index/backlog/\nexpected.tsv wiring.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
5d7319a	author	Will Norris
5d7319a	added	12
5d7319a	deleted	7
5d7319a	files	1
5d7319a	body	#12 CORDIC rotator is built, gate-passes (bsnes-jg 0x4D41, multiply-free),\nand published; mark it done in the demo-ideas backlog (main entry, coverage\nmap, recommended-picks). #5 Life left open — built but not yet published.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
070328f	author	Will Norris
070328f	added	4
070328f	deleted	3
070328f	files	1
070328f	body	Demo #10 of the compiler stress-test battery: the many-multiply member. A sum\nof rotating vectors P(t) = Σ c_k·exp(i·2π·f_k·t) traces a baked outline; the\nhot loop is a sin/cos-LUT sweep with FOUR 16×16→32 multiplies per harmonic\n(the complex multiply re·cos−im·sin / re·sin+im·cos) + 32-bit accumulation —\n__mulsi3-dense and divide-free, a distinct profile from the divide-bound\nspirograph (#11) and n-body (#13).\n\nShared examples/65816/epicycles.h drives the host oracle, corpus slice, and ROM.\nCoefficients are the DFT of a 5-pointed star (tools/gen-epicycles-tables.py),\nordered by magnitude; the star is rotated ~23° off-vertical so both re and im\nare non-zero — a symmetric star gives purely-imaginary c_k and folds the\nreal-part multiplies to ×0, halving the intended stress. 8 harmonics.\n\nGate epi_gate_crc = 0x4F6C (32 points spanning the full period). No far pointers\n⇒ full 5-way bar. Verified: dev/run.sh epicycles RESULT PASS (disasm __mulsi3=4\n+ rep/sep=28, divide=0; bsnes-jg host==default==+mos-a16==+mos-xy16 == 0x4F6C;\n-verify-machineinstrs clean all three; UBSan clean). The on-screen star draws\nitself over its dim generating circle (BitmapCanvas bloom + scaffold). MAME leg\npending the SPC700 IPL (bsnes-jg + browser carry the demo bar).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f8aff1c	author	Will Norris
f8aff1c	added	5
f8aff1c	deleted	3
f8aff1c	files	1
f8aff1c	body	Demo #17 of the compiler stress-test battery: the recursion / soft-stack /\nframe-ABI member. Recursive sr_qsort + sr_msort (noinline) force the reentrant\nsoft-stack spill path (an array pointer lives across the self-jsr — the\na16spillr.c machinery in a real workload); iterative sr_hsort is the\nnon-recursive contrast. On-screen animation is record/replay (each sort emits an\nop-log of position:=value stores; the ROM replays 1 op/algo/frame, repainting\ntouched columns) so GENUINE recursion stays the compiler stress while three bar\narrays race to sort in real time.\n\nGate: sortrace_gate_crc() folds 8 rounds, each asserting all three sorts agree\non the identity permutation, then folding each algorithm's cmps^moves.\ndev/run.sh sort-race RESULT PASS — host == bsnes-jg 0xB28F; disasm gate\nrecursion(sr_qsort/sr_msort refs=695) + cmp=44 + rep/sep=233, zero 32-bit\nlibcalls; default/+mos-a16/+mos-xy16 -verify-machineinstrs clean. MAME leg SKIPs\n(env-wide SPC700 IPL absent; non-blocker per the 2026-06-28 demos policy).\n\nFiles: examples/65816/sort-race.h, examples/snes/sort-race.c,\nexamples/snes/corpus/sort-race_sim.c, tools/sort-race-sim.c, dev/sort-race.{sh,lua},\nTaskfile.yml, TODO.md, docs (plan + demo-ideas strike).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
32a4114	author	Will Norris
32a4114	added	3
32a4114	deleted	3
32a4114	files	1
32a4114	body	Demo #7 of the compiler stress-test battery. The classic PSX-Doom fire: a\n32×28 heat grid rises and flickers from a constant max-heat source row through\na 16-colour black→red→orange→yellow→white CGRAM ramp on BG1 4bpp (one solid\ntile per cell, half-tilemap DMA split over 2 frames).\n\nDeliberately the multiply-/divide-FREE member of the battery — the hot loop is\na flat-index 8-bit array sweep (lda/sta (zp),y over a variable write offset)\nplus a 16-bit xorshift16 PRNG per non-zero cell (native eor/asl/lsr under one\nrep/sep bracket). It exercises indexed array bandwidth + the PRNG, the corners\nthe arithmetic demos (rdiff/n-body/spigot) don't hit.\n\nShared host+target header examples/65816/doom-fire.h (fire_step + xorshift16 +\ndoomfire_gate_crc). No far pointers ⇒ full 5-way bar. Verified:\n  dev/run.sh doom-fire RESULT PASS — host oracle == bsnes-jg corpus_result\n  0x3C59 (16×16 gate grid, 30 steps); disasm gate eor=6 asl/lsr=8 rep/sep=21,\n  zero __mulsi3/__udivmodsi4. bsnes-jg framebuffer shows textbook rising fire.\n  MAME leg SKIPped (SPC700 IPL absent — env-wide non-blocker, demos-only policy).\n\nFiles: examples/65816/doom-fire.h, examples/snes/doom-fire.c,\nexamples/snes/corpus/doom-fire_sim.c, tools/doom-fire-sim.c,\ndev/doom-fire.{sh,lua}, docs/plans/2026-06-28-7-snes-doom-fire.md + tracking.\n(Taskfile.yml + expected.tsv doom-fire rows landed in 9f3d71e — a concurrent\nagent's git add swept them into the #18 maze commit; content is correct.)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
