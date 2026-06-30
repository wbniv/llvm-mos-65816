| Date | Change |
|------|--------|
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/661b01e) | #33 Double-Precision Mandelbrot SNES demo — 64-bit double soft-float |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/b24713b) | docs(demo-ideas): Round 3 — 20 new compiler-stress demo ideas (#33–#52) |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/66271bb) | docs(battery): add stress-test battery completion status report |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/fbaf268) | docs(demo-ideas): Round 2 complete — strike #29a coverage row + update status header |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/b1aa00a) | snes(#31): Barnes-Hut quadtree galaxy — pointer-chasing dynamic trees |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/e7d1965) | snes(#32): va_arg variadic formatter — mini_sprintf + Lissajous |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/39f1972) | snes(#25): 32-point DIT FFT spectrum analyser — butterfly __mulsi3 + bit-reversal |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/8e1dd62) | snes(#28): Hilbert space-filling curve — __ashlsi3+__lshrsi3 variable-count shifts |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/3e6c825) | snes(#27,#30): times-table cardioid + TEA cipher — __umodsi3 + 32-bit shift/add/XOR |
| [2026-06-30](https://github.com/wbniv/llvm-mos-65816/commit/471d04f) | snes(fn-plot): #24 recursive-descent float function plotter — 5-way green |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/6fe6e69) | feat(snes): #29b Truchet (packed bitfields) — bitfield insert/extract stress demo |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/8ed73d1) | feat(snes): #29a Bytecode-VM Turtle — jump-table + function-pointer dispatch demo |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/d5a4f74) | feat(snes): #26 Boids Flock — struct-by-value / aggregate-return ABI stress demo |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/7172dd9) | feat(snes): #22 64-Bit Avalanche — splitmix64 hash matrix / 64-bit integer libcall stress demo |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/cd3663a) | feat(snes): #21 Soft-Float Mandelbrot — IEEE-754 single-precision escape-time / soft-float libcall stress demo |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/673b64b) | docs(investigation): add Round 2 (#21+) — new codegen-corner demos |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/4d2611d) | docs(investigation): mark demo battery complete (20/20) + strikethrough self-note |
| [2026-06-29](https://github.com/wbniv/llvm-mos-65816/commit/8e6f647) | feat(snes): #3 Burning Ship fractal — |Re|,|Im|-folding escape-time demo |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/0cabf2d) | feat(snes): #1 Julia Set Explorer — z²+c complex-multiply / far-framebuffer stress demo |
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/579ad86) | feat(snes): #15 Raycaster maze — DDA grid-cast, per-column 1/dist divide |
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
661b01e	author	Will Norris
661b01e	added	4
661b01e	deleted	4
661b01e	files	1
661b01e	body	The double analogue of #21 (mandel-float): escape-time z^2+c in IEEE-754\n64-bit `double` (top half) beside the 32-bit `float` twin (bottom half),\nMode-7 far-buffer renderer (+mos-a16-only). Exercises the entire double\nsoft-float library (__muldf3/__adddf3/__subdf3/__gtdf2/__floatsidf +\n__truncdfsf2/__extendsfdf2) — disjoint from #22's 64-bit integer family,\notherwise untested by the battery.\n\nBit-exact host==default==+mos-a16==+mos-xy16==0x0EDF on bsnes-jg (all three\ncompiled modes); disasm __muldf3=8/__add+subdf3=12/rep-sep=31. MAME leg\nenv-blocked (no SPC700 IPL). ROM fit one 32 KiB bank by const-folding the\ncoordinate divides (the huge double lib pushed it 2289 B over).\n\nCompiler finding: a NEW (3rd) witness of the documented\na16-rc-undef-ra-pure-virtual known issue (CAUSE #2) — the a16/xy16 corpus\nslice trips -verify 'undefined physical register' (same symptom the shipped\nmandel-float slice emits) but runs bit-exact correct (proven by the 4-way\nbsnes-jg differential incl. the flagged xy16 mode). Latent-hazard verify\nXFAIL, not a miscompile; not reshaped to dodge it per the stress protocol.\n\nPublished: biohack.net/snes/mandel-double/ (v1.0.150).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
b24713b	author	Will Norris
b24713b	added	173
b24713b	deleted	0
b24713b	files	1
b24713b	body	Twenty more codegen corners none of the first 32 demos touch, each with a\nvisual: double soft-float, libm/sqrtf, setjmp/longjmp, alloca/VLA, sparse-switch,\ncomputed-goto, constant-divisor magic reciprocal, table-LUT CRC32, free-list\nallocator, Duff's device, signed-64 divide, saturating/overflow-builtin, union\ntype-punning, qsort callbacks, Newton reciprocal, IIR feedback, LZ/RLE decode,\n8+-arg calling-convention spill, coroutines/protothreads, cross-boundary bitfields.\n\nIncludes a per-corner coverage map + Round 3 first picks, and two up-front design\ngotchas: libm transcendentals aren't bit-exact across libms (only sqrtf + the basic\nops are correctly-rounded — must self-ship sin/exp or restrict to sqrtf), and\nsetjmp/alloca may not be supported by the soft-stack target (a gap is itself a\nfinding). Header status updated. Not yet built.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
66271bb	author	Will Norris
66271bb	added	1
66271bb	deleted	0
66271bb	files	1
66271bb	body	All 32 demos shipped + gate-verified + published. Consolidates the\ncompiler-correctness verdict (all corners green, bugs found were pre-existing\nand fixed in-flight), the Round-2 coverage table with gate CRCs, and the\n#25-FFT display-vs-codegen distinction. Linked from the demo-ideas tracker.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
fbaf268	author	Will Norris
fbaf268	added	10
fbaf268	deleted	10
fbaf268	files	1
fbaf268	body	All 32 numbered demos (#1-#20 Round 1, #21-#32 Round 2) now shipped and published.\nEvery Round-2 codegen corner came back green; no new compiler bug surfaced (the\n#23 in-place-memmove xy16 miscompile was fixed in-flight during that demo).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
b1aa00a	author	Will Norris
b1aa00a	added	5
b1aa00a	deleted	5
b1aa00a	files	1
b1aa00a	body	Recursive bh_insert/bh_force walk a pooled-node quadtree via runtime child[]\nindices (ZP-indexed indirect loads + tree-shaped JSR-to-self call graph) —\nthe linked-tree corner distinct from #13's flat-array N-body and #18's flat heap.\nFused with gravity kernel: __mulsi3=5, __divsi3=4. bh_force self-recursion 447\nrefs, rep/sep=160. Gate 0xEF0B; 5-way green. Published: biohack.net/snes/bhut/.\n\nDeliberate heavy grind (~1 step/25 frames): the recursive call graph + divide\npath run continuously — that IS the stress. No miscompile found; tree-walk\ncodegen correct across all modes.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
e7d1965	author	Will Norris
e7d1965	added	2
e7d1965	deleted	2
e7d1965	files	1
e7d1965	body	mini_sprintf(%u/%d/%x) exercises the variadic calling convention on the 65816:\nva_arg(ap, unsigned int) reads 2 bytes on target (16-bit int) vs 4 on x86 host.\nSmall-value gate avoids width divergence → bit-exact 5-way green.\nGate 0xE1F3; jsr=7 (4 mini_sprintf + 3 helpers); rep/sep=45; __mulsi3=0.\nPublished: biohack.net/snes/vaprintf/ (v1.0.145).\n\nNo miscompile found — variadic va_arg codegen correct across all modes.\nFirst demo in the battery to exercise the variadic calling convention.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
39f1972	author	Will Norris
39f1972	added	3
39f1972	deleted	3
39f1972	files	1
39f1972	body	5 stages × 16 butterflies × 4× __mulsi3 = 320 multiply calls per FFT frame.\nBit-reversal permutation via precomputed FFT_BITREV[32] table (new corner).\nGate 0x6D7A; __mulsi3=4, rep/sep=63; 5-way green. Sweeping tone animation.\nPublished: biohack.net/snes/fft/ (v1.0.143).\n\nNo miscompile found — FFT butterfly codegen correct across all modes.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8e1dd62	author	Will Norris
8e1dd62	added	5
8e1dd62	deleted	5
8e1dd62	files	1
8e1dd62	body	Order-4 d2xy/xy2d bijection; loop variable k (0..3) drives rx<<k, ry<<k, 1<<k\nat runtime → __ashlsi3=5, __lshrsi3 confirmed; rep/sep=23, __mulsi3=0.\nRound-trip hil_xy2d(hil_d2xy(d))==d verified for all 256 points.\nGate 0x5999; 5-way green. Published: biohack.net/snes/hilbert/ (v1.0.142).\n\nThis opens the variable-count 32-bit shift corner (#28,#30 coverage map row)\nthat TEA #30 targeted but missed (TEA's constant <<4/>>5 get inlined at -Os).\nNo miscompile found; variable-count shift codegen correct across all modes.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
3e6c825	author	Will Norris
3e6c825	added	3
3e6c825	deleted	3
3e6c825	files	1
3e6c825	body	#27 cardioid: chord from i to k*(i+65536)%N for k=2..30, N=200.\n  Gate 0x523B; __mulsi3=1, __umodsi3=1, rep/sep=6; 5-way green.\n  Published: biohack.net/snes/cardioid/ (v1.0.140).\n\n#30 TEA: 32-round Tiny Encryption Algorithm, 16 key-variant avalanche.\n  Gate 0xDF0E; __mulsi3=0, shift_libcalls=0, rep/sep=22; 5-way green.\n  Published: biohack.net/snes/tea/ (v1.0.141).\n\nBoth open novel codegen corners: modulo-heavy (__umodsi3 sole hot op) and\n32-bit add/XOR/shift-only (multiply-free) paths the prior 24 demos never ran.\nNo miscompile found on either; differential confirmed host==+mos-a16==+mos-xy16.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
471d04f	author	Will Norris
471d04f	added	12
471d04f	deleted	12
471d04f	files	1
471d04f	body	Adds the fn-plot compiler stress-test demo (Round 2, battery #24):\n  - examples/65816/fn_plot.h: recursive-descent parser + IEEE-754 soft-float\n    evaluator; fn_gate_crc evaluates x*x-0.5 at 64 pts → 0x2EBE\n  - examples/snes/fn-plot.c: SNES ROM; BitmapCanvas + TextLayer; 4 baked\n    expressions cycle automatically at 1 px/frame\n  - examples/snes/corpus/fn_plot_sim.c: corpus slice; added to expected.tsv\n  - tools/fn-plot-sim.c: host oracle\n  - dev/fn-plot.sh + dev/fn-plot.lua: gate script\n\nGate: __mulsf3=5, __divsf3=1, rep/sep=48; bsnes-jg host==+mos-a16 0x2EBE.\nMAME: SKIP (no SPC700 IPL — demos-only non-blocker). No compiler bug found.\nPublished biohack.net/snes/fn-plot/ (v1.0.138).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
6fe6e69	author	Will Norris
6fe6e69	added	2
6fe6e69	deleted	2
6fe6e69	files	1
6fe6e69	body	Round-2 (new-codegen-corner) demo. No prior demo uses C bitfields; this packs every cell\ninto a 16-bit bitfield struct (orient:1/style:1/hue:3/phase:2/mark:1/energy:4) and a wave\nripples through a 16x16 '10 PRINT'/Truchet diagonal maze, reading/writing fields each step\n+ redraw -> the bitfield insert/extract codegen (mask and + merge ora + shift, pure ALU,\nNO libcalls) runs continuously.\n\nBitfield-width subtlety: unsigned is 32-bit host / 16-bit target, so fields are declared\nuint16_t:n (identical 16-bit unit, sizeof(Cell)==2) and the gate folds EXTRACTED values, so\na divergence = a real insert/extract miscompile, not a legal layout diff. Verified bit-exact\nhost == default == +mos-a16 == +mos-xy16 == 0xB3E6 on bsnes-jg; disasm and=13/ora=8/shift=32/\nrep-sep=59/libcalls=0. No compiler bug. Display: snesgfx BitmapCanvas maze, pulsed-source\ncolour ripples, palette cycle.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8ed73d1	author	Will Norris
8ed73d1	added	6
8ed73d1	deleted	5
8ed73d1	files	1
8ed73d1	body	Demo #29a of the compiler stress-test battery (Round 2). A stack-machine bytecode\ninterpreter draws LOGO turtle graphics: the main switch(op) over a dense opcode\nrange lowers to a JMP (abs,X) jump table (the JMPIdxIndir pseudo the xy16\nrequiredXWidth hardening singled out) and the binary ALU ops dispatch through a\nstatic-const function-pointer opcode table (jsr __call_indir) — the indirect /\ncomputed control-flow corners no other demo runs.\n\nInteger fixed-point (Q8.8 turtle in int32, SINCOS 8.8 LUT) => bit-exact; near\nfunction pointers + bank-0 data => full 5-way bar. corpus gate vm_gate_crc = 0x4007\n(180-segment program). dev/run.sh turtle-vm RESULT PASS: disasm jump-table=1 +\n__call_indir=1 + __mulsi3=2 + rep/sep=155; bsnes-jg host==+mos-a16 0x4007. 5-way\nconfirmed host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean — a live\ncross-mode confirmation of the JMPIdxIndir index-width fix (incl. xy16, where the\njump table indexes with a 16-bit X). No compiler bug. Draws a woven multi-colour\nspiral rosette = the visual proof.\n\nPublished biohack.net/snes/turtle-vm/ (v1.0.130).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d5a4f74	author	Will Norris
d5a4f74	added	6
d5a4f74	deleted	5
d5a4f74	files	1
d5a4f74	body	Demo #26 of the compiler stress-test battery (Round 2). Reynolds flocking built\non a vec2 {int16_t x,y} VALUE type whose steering kernel (v2_add/v2_sub/v2_scale\n+ separation/alignment/cohesion) TAKES and RETURNS the struct BY VALUE, noinline\nso the O(N^2)/frame calls survive -Os — the small-struct register-pair-vs-sret\naggregate-return path no other demo passes a struct through.\n\nInteger fixed-point (Q12.4) => bit-exact; flock in bank-0 WRAM (no far pointers)\n=> full 5-way bar. corpus gate boids_gate_crc = 0xA8AB (8-bird flock, 12 steps).\ndev/run.sh boids RESULT PASS: disasm by-value-calls=497 + __mulsi3=6 + __divsi3=4\n+ rep/sep=103; bsnes-jg host==+mos-a16 0xA8AB. 5-way confirmed host==default==\n+mos-a16==+mos-xy16 on bsnes-jg, -verify clean (MAME SKIP — no SPC700 IPL,\ndemos-only non-blocker). No compiler bug — aggregate-return ABI correct in all\nmodes. Boids coloured by heading octant = the visual proof.\n\nPublished biohack.net/snes/boids/ (v1.0.128).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
7172dd9	author	Will Norris
7172dd9	added	7
7172dd9	deleted	6
7172dd9	files	1
7172dd9	body	Round-2 (new-codegen-corner) demo. Every Round-1 demo tops out at 32-bit; this one mixes\nuint64_t, so on the 16-bit 65816 each op is a multi-limb libcall: __muldi3, __lshrdi3/\n__ashldi3 (incl. variable 1ULL<<i and whole-limb >>32), __udivdi3, __adddi3, 64-bit xor.\n\nBit-exact differential (64-bit integer ops are exact): host == default-8bit == +mos-a16 ==\n+mos-xy16 == 0x27EA on bsnes-jg; disasm __muldi3=2, 64-bit shift, __udivdi3=1, rep/sep=19.\nNo bug found. Visual: cell (i,j) = output bit j of hash64(seed^(1<<i)) -> a ~50%-dense\nrainbow avalanche field. bank-0 buffer (5-way), Mode-7. Published biohack.net/snes/avalanche/.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
cd3663a	author	Will Norris
cd3663a	added	8
cd3663a	deleted	7
cd3663a	files	1
cd3663a	body	First Round-2 (new-codegen-corner) demo of the compiler stress-test battery. Renders the\nMandelbrot set in IEEE-754 single-precision float, so on the FPU-less 65816 every op is a\nsoft-float libcall (__mulsf3/__addsf3/__subsf3/__divsf3/__gtsf2/__floatsisf) — the library\nno Round-1 demo touches.\n\nBit-exact differential: single precision is fully specified (correctly-rounded), so host\nx86 single == target soft-float bit-for-bit. FMA contraction (the one divergence risk) is\nforbidden by construction — every op is its own statement, no a*b±c to fuse. Verified\nhost == default-8bit == +mos-a16 == +mos-xy16 == 0x4169 on bsnes-jg; disasm __mulsf3=8,\n__add/subsf3=12, rep/sep=35. No compiler bug found — soft-float codegen is correct in all\nmodes. 16x14 grid 4x-upscaled into the $7E2000 far framebuffer, Mode-7 zoom, progressive\nboot-paint. Published biohack.net/snes/mandel-float/.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
673b64b	author	Will Norris
673b64b	added	80
673b64b	deleted	3
673b64b	files	1
673b64b	body	Round 1 (#1-20) shipped and its differential gate surfaced several\npre-existing compiler bugs, all in libcall/ABI paths. Round 2 targets\nthe codegen families the first 20 never execute — soft-float, 64-bit\nintegers, jump tables, by-value struct ABI, bitfields, variadics,\nvariable-count shifts, pointer-chasing trees — with an untested-corner\ncoverage map. Also restore the round-status banner and re-strike #4\nBuddhabrot (dropped by concurrent-tree churn).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
4d2611d	author	Will Norris
4d2611d	added	14
4d2611d	deleted	15
4d2611d	files	1
4d2611d	body	All 20 stress-test demo ideas now shipped/published. Add completion\nbanner, strike the coverage-map numbers and each row's aspect label per\nthe ~~done~~ convention, fix a duplicated table header and a malformed\ndouble-tilde token. Record a NOTE-TO-SELF to apply strikethrough to\ncompleted items consistently everywhere (index tables included).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
8e6f647	author	Will Norris
8e6f647	added	17
8e6f647	deleted	14
8e6f647	files	1
8e6f647	body	Demo #3 of the compiler stress-test battery — the abs-fold fractal. The\nMandelbrot's folded cousin z_{n+1} = (|Re z| + i|Im z|)² + c. Per\niteration three Q12 __mulsi3 (zx², zy², |zx·zy|) — the same count as\nMandelbrot — PLUS the two abs folds that ARE the algorithm (and make the\nship). Escape-time bands render the black ship silhouette; the whole\n32×28 grid is ground out once behind the title (too heavy for a 60 fps\nreveal — interior cells run the full iteration count) then the bands are\npalette-cycled. Multiply-only, no divide.\n\nGate bs_gate_crc = 0x6F2D (16×16 window over the ship, maxiter 24,\nescape-count rotate-XOR hash). No far pointers => full 5-way bar.\nVerified: dev/run.sh burning-ship RESULT PASS (disasm __mulsi3=3 +\nrep/sep=26, divide=0; bsnes-jg host==+mos-a16 0x6F2D;\n-verify-machineinstrs clean on default/+mos-a16/+mos-xy16; MAME pending\nthe SPC700 IPL — non-blocker per the demos-only policy). Published\nbiohack.net/snes/burning-ship/ (biohack.net v1.0.118).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
0cabf2d	author	Will Norris
0cabf2d	added	4
0cabf2d	deleted	4
0cabf2d	files	1
0cabf2d	body	The Mandelbrot demo's morphing cousin: iterates z²+c in Q5.10 with z₀ = the\npixel and c a single constant per frame, swept along the 0.7885·e^iθ orbit so\nthe set continuously morphs. Three 16×16→32 __mulsi3 per iteration; the escape\nimage is far-stored into a high-WRAM buffer at $7E2000 (the #320 sta [dp] path)\nand far-loaded back into Mode 7 VRAM. A full 64×56 recompute is ~22 s on the\n65816, so the set is re-ground a coarse row per spin frame in the background\nwhile the Mode 7 affine matrix spins + zoom-breathes it at 60 fps.\n\nShared kernel examples/65816/julia.h (host oracle + corpus slice + ROM). Gate\njulia_gate_crc 0x3490 (4 keyframe c over a 6×6 grid, maxiter 8 — far-pointer-free,\nso the corpus slice is a full 5-way bar; finishes by ~frame 90, inside the\n180-frame corpus budget). dev/run.sh julia PASS on the demo bar (disasm\n__mulsi3=3 + rep/sep=46; bsnes-jg host==+mos-a16 0x3490; MAME SKIP — no SPC700\nIPL in this env, demos-only non-blocker). Published biohack.net/snes/julia/.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
579ad86	author	Will Norris
579ad86	added	3
579ad86	deleted	3
579ad86	files	1
579ad86	body	Demo #15 of the compiler stress-test battery — the division member. A\nWolfenstein-style grid raycaster auto-walks a 16×16 maze: each of 64\nscreen columns marches a ray cell-to-cell by integer DDA and draws the\nwall slice at screen_h / perpendicular_distance. Three __udivsi3 per\ncolumn (two deltaDist = |1/rayDir| reciprocals + the 1/dist projection)\n— the only division-bound demo. Camera-plane basis from a Q8.8 sine LUT\n(fisheye-free); distance-shaded slices into a BitmapCanvas, 2-row HUD.\n\nGate rc_gate_crc = 0xB200 (64-column fan, fixed camera, rotate-XOR fold\nof wall height + side). No far pointers => full 5-way bar. Verified:\ndev/run.sh raycaster RESULT PASS (disasm __udivsi3=3 + rep/sep=51;\nbsnes-jg host==+mos-a16 0xB200; -verify-machineinstrs clean on\ndefault/+mos-a16/+mos-xy16; MAME pending the SPC700 IPL — non-blocker\nper the demos-only policy). Published biohack.net/snes/raycaster/\n(biohack.net v1.0.117).\n\nThe differential caught a real bug: the axis-aligned-ray deltaDist\nsentinel 0x3FFFFFF made frac*sentinel (256*0x3FFFFFF ~ 8.6e9) overflow\nsigned int32 — UB the host -O2 and target -Os builds optimised\ndifferently (host 0x724B != target 0xB200). Shrunk to 0x400000 (keeps\n256*sentinel < 2^31, still exceeds any real accumulated sideDist); also\nfixed RC_VIEWH*256 (128*256 overflows int16 on the 16-bit target) ->\n(int32_t)RC_VIEWH * 256.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
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
