# SNES 65816 compiler stress-test demos (algorithm + visual)

> **Status (2026-06-30).** **Round 1 (#1–#20) — all 20 shipped** ✓ and **Round 2 (#21–#32) — all shipped** ✓,
> published on [biohack.net/snes](https://biohack.net/snes/); the differential gate found a handful of
> pre-existing compiler bugs along the way. Round 2 each targets a
> **codegen corner the first 20 never execute** — soft-float (#21), 64-bit integers (#22),
> string libcalls (#23/#24), recursive-descent parser (#24), FFT butterfly + bit-reversal (#25),
> by-value struct ABI (#26), modulo-heavy (#27), variable-count shifts (#28), jump-table + bitfields
> (#29a/#29b), 32-bit shift/add/XOR (#30), pointer-chasing trees (#31), variadic va_arg (#32) — the
> untested libcall/ABI paths where the remaining bugs hid. **All Round-2 corners came back green: no new
> compiler bug surfaced** (the #23 in-place-memmove xy16 miscompile was fixed in-flight; see its row).
> **Completion summary:** [`2026-06-30-stress-test-battery-status.md`](2026-06-30-stress-test-battery-status.md).
>
> **Round 3 (#33–#52) — COMPLETE** ✓ (2026-06-30). Twenty more codegen corners none of the first 32
> touch — `double` soft-float, libm transcendentals, `setjmp`/`longjmp`, `alloca`/VLA, sparse-switch,
> computed-`goto`, constant-divisor magic reciprocal, table-LUT CRC, free-list allocator, Duff's device,
> signed-64 divide, saturating/overflow-builtin arithmetic, union type-punning, `qsort` callbacks,
> Newton-Raphson refinement, IIR feedback, LZ/RLE decode, many-arg calling-convention spill,
> coroutines/protothreads, and cross-byte-boundary bitfields. **All buildable demos shipped** (18 of 20):
> only **#34** (no libm `sqrtf` — library gap) and **#35** (`longjmp` broken — 6502-only `setjmp.S`
> toolchain gap; deferred) are non-buildable and documented as such. **One real compiler bug found +
> fixed:** **#46** surfaced a backend crash — the `(x>y)-(x<y)` comparator idiom emits the newer `G_SCMP`
> three-way-compare opcode, which `MOSLegalizerInfo` had **no legalization rule for** (`unable to legalize
> G_SCMP`, in default/a16/xy16 alike). Fixed with a one-line `.lower()` (patch `0016-mos-scmp-ucmp-legalize`,
> routing to LLVM's `lowerThreewayCompare`); **standalone-testable, queued upstream** in
> [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md). Every other Round-3 corner
> came back green — no further compiler bug.
>
> **Round 4 (#53–#72) — IN PROGRESS** (#53–#61 shipped). **#61 (Diffie–Hellman 64-bit modexp) 🐞 CAUGHT +
> FIXED A REAL BACKEND BUG** — the `+mos-a16`/`+mos-xy16` legalizer had no rule for `G_UNMERGE_VALUES`
> splitting an `s64` into 16-bit lanes (nor odd-width `G_ANYEXT`), crashing on any 64-bit-arithmetic-heavy
> program (default 8-bit was fine). Fixed with the s64↔s16 (un)merge glue mirroring the existing s32 glue +
> routing odd-width anyext through zext (patch `0017`, corpus 62/62 green, queued upstream). Twenty corners
> none of the first 52 execute, each grounded in a **verified** backend path: the **bit-population intrinsic
> family** (`__popcountsi2`/`__clzsi2`/`__ctzsi2`/`__paritysi2` + the inline `G_CTLZ`/`G_CTTZ`/`G_CTPOP`
> lowering at `MOSLegalizerInfo.cpp:308`), byte-swap / bit-reverse intrinsics (`__bswapsi2`;
> `G_BITREVERSE.lower()` @186), **widening multiply-high** (`G_UMULH`/`G_SMULH.lower()` @300),
> **branchless min/max/abs** (`G_SMIN`/`G_SMAX`/`G_UMIN`/`G_UMAX.lower()` @272, `G_ABS.custom()` @281),
> **NaN / unordered float compares** (`__unordsf2`/`__eqsf2`/`__nesf2`), **64-bit⇄float conversion**
> (`__floatdidf`/`__fixdfdi`/`__floatdisf`), the libc **`div()`/`ldiv()` `div_t` struct-return** over the
> custom `G_SDIVREM` legalizer (@229), plus data-structure/algorithm corners the battery never ran —
> union-find path-compression, Fenwick `i&-i`, non-comparison (radix/counting) sort, convex-hull
> orientation tests, 2-D dynamic-programming tables, Huffman bit-tree decode — and rendering techniques
> with distinct codegen (widening-mul rotozoom, barycentric edge-function fill, Floyd–Steinberg error
> diffusion, marching-squares contours, gradient noise, 3-D `grid[z][y][x]` multi-dim indexing). Every
> symbol/opcode cited was confirmed present in `vendor/llvm-mos/` before drafting.

A backlog of candidate demo programs whose job is to **stress the llvm-mos 65816 codegen** — each leans
on a different corner of the compiler (32-bit/fixed-point multiply, division, recursion + the soft stack,
multi-precision carry chains, bit manipulation, shift-add, far/high-WRAM pointers under `+mos-a16`, function
pointers) **and renders the computation itself** on screen, so the visual *is* the proof, not a side channel.

These complement the demos already built: the fixed-point **Mandelbrot** (Mode 7, far stores —
[`examples/snes/mandel-display.c`](../../examples/snes/mandel-display.c)), the **Blossom** Hopalong attractor ✓ [/snes/blossom/](https://biohack.net/snes/blossom/),
and **Space Invaders** on the `snesgfx` OOP library ✓ [/snes/space-invaders/](https://biohack.net/snes/space-invaders/)
([plan](../plans/2026-06-26-space-invaders-on-the-snesgfx-oop-library.md)). None of the 20 below duplicate those.

## The bar each demo should meet (so it's a real test, not a toy)

Mirror the established pattern (see `mandel.h` / `invaders_logic.h`):

1. **Shared host+target logic header** — the math/algorithm in pure `<stdint.h>` C (explicit `int16_t`/`int32_t`
   widths; `int` is 16-bit on target, 32-bit on host), compiled both on the SNES and by a host oracle.
2. **Differential CRC** — fold the result/state into a CRC; assert **host == default/+mos-a16@bsnes-jg**,
   `-verify-machineinstrs` clean, bsnes 3× byte-identical. **MAME is optional for demos** (the user
   final-verifies each demo in the browser, which runs the same bsnes-jg core) — so a pending/flaky MAME
   leg (e.g. SPC700 IPL) does **not** block a demo. Run the MAME legs (`default`/`+mos-a16`/`+mos-xy16`)
   when convenient as a bonus cross-check, but bsnes-jg PASS + browser is the demo bar. (The **core compiler
   fuzzer / micro-test gate is unchanged** — it still requires the full host==default==a16==xy16 on
   MAME + bsnes-jg; this relaxation is demos-only.)
3. **On-screen render via `snesgfx`** — sprites or a Mode 7 / BG buffer that visualises the computation;
   bsnes-jg screenshot (MAME screenshot optional).

Builds default-8-bit unless it needs a far/high-WRAM framebuffer (then `+mos-a16`, like Mandelbrot).

---

## Fractals & complex iteration — fixed-point mul/div, tight per-pixel loops

1. ~~**Julia set explorer** — `z²+c` with `c` animated along a path. *Stresses:* Q-format complex multiply,
   far high-WRAM framebuffer (a16). *Shows:* morphing Julia fractal.~~ ✓ [/snes/julia/](https://biohack.net/snes/julia/)
2. ~~**Newton's-method fractal** — `z − p(z)/p′(z)` for `z³−1`, colour by which root it converges to.
   *Stresses:* complex **division** (the hard one) + convergence branching. *Shows:* basins of attraction.~~ ✓ [/snes/newton/](https://biohack.net/snes/newton/)
3. ~~**Burning Ship / Multibrot** — `|Re|,|Im|` folding, or `zᵈ`. *Stresses:* extra multiplies, abs, `pow`
   loops. *Shows:* the ship / d-fold bulb.~~ ✓ [/snes/burning-ship/](https://biohack.net/snes/burning-ship/)
4. ~~**Buddhabrot** — accumulate *escaping* orbit visits into a density buffer. *Stresses:* scatter writes to a
   far buffer + PRNG sampling. *Shows:* the ghostly orbit-density image.~~ ✓ [/snes/buddhabrot/](https://biohack.net/snes/buddhabrot/)

## Cellular automata & grids — bit-twiddling, array indexing, double-buffer

5. ~~**Conway's Game of Life** — bit-packed neighbour sums, ping-pong buffers. *Stresses:* bitops, array index,
   two-buffer swap. *Shows:* gliders/guns evolving.~~ ✓ [/snes/life/](https://biohack.net/snes/life/)
6. ~~**Rule 90/110 (1-D CA)** — each row from the previous via 8-bit logic. *Stresses:* shifts/boolean logic.
   *Shows:* Sierpinski (90) / chaos (110) scrolling down — the display *is* the computation.~~ ✓ [/snes/1d-ca/](https://biohack.net/snes/1d-ca/)
7. ~~**Doom-fire / heat field** — per-cell decay + PRNG, palette ramp. *Stresses:* array sweep + rng + CGRAM.
   *Shows:* animated fire from the heat array.~~ ✓ [/snes/doom-fire/](https://biohack.net/snes/doom-fire/)
8. ~~**Reaction–diffusion (Gray–Scott)** — two-chemical PDE, Laplacian, mul-add per cell. *Stresses:* heavy
   fixed-point **mul-add** loops. *Shows:* Turing spots/stripes self-organising.~~ ✓ [/snes/rdiff/](https://biohack.net/snes/rdiff/)

## Trig / parametric — sin-cos LUTs, fixed-point accumulation

9. ~~**Lissajous / harmonograph** — damped `sin(at), sin(bt+φ)` plotting. *Stresses:* sin LUT + fixed-point mul
   + accumulation. *Shows:* the decaying traced curve.~~ ✓ [/snes/harmonograph/](https://biohack.net/snes/harmonograph/)
10. ~~**Fourier epicycles** — sum of rotating vectors traces a shape. *Stresses:* many sin/cos + complex add.
    *Shows:* nested circles drawing an outline.~~ ✓ [/snes/epicycles/](https://biohack.net/snes/epicycles/) *(8 baked
    DFT coefficients of a 5-pointed star; 4 `__mulsi3` per harmonic + 32-bit accumulate, divide-free.)*
11. ~~**Spirograph (hypotrochoid)** — `(R, r, d)` parametric. *Stresses:* sin/cos + mul. *Shows:* the rose pattern.~~ ✓ [/snes/spirograph/](https://biohack.net/snes/spirograph/)
12. ~~**CORDIC clock/rotator** — sin/cos/atan via **shift-add only** (no multiply). *Stresses:* shift-add
    convergence loops — a different ALU profile from everything else. *Shows:* a rotating hand with its angle.~~ ✓ [/snes/cordic/](https://biohack.net/snes/cordic/)

## Physics & numerical integration — fixed-point, division, sqrt

13. ~~**N-body orbits** — Newtonian gravity, Verlet, `1/r²`. *Stresses:* fixed-point mul + **division** +
    integration. *Shows:* planets orbiting with fading trails.~~ ✓ [/snes/n-body/](https://biohack.net/snes/n-body/)
14. ~~**Double pendulum (chaos)** — Euler/RK integration with sin. *Stresses:* sin + sensitive fixed-point
    integration. *Shows:* the chaotic swing + path trace.~~ ✓ [/snes/double-pendulum/](https://biohack.net/snes/double-pendulum/)
15. ~~**Raycaster maze** — DDA grid cast, wall height = `1/dist` per column. *Stresses:* fixed-point +
    **per-column division**. *Shows:* first-person 3-D corridors.~~ ✓ [/snes/raycaster/](https://biohack.net/snes/raycaster/)
16. ~~**Wireframe 3-D solid** — rotation matrix (sin/cos LUT), perspective projection (divide), Bresenham lines.
    *Stresses:* 3×3 matrix mul + projection divide + line raster. *Shows:* a spinning cube/icosahedron.~~ ✓ [/snes/3d-wireframe/](https://biohack.net/snes/3d-wireframe/)

## Discrete algorithms, data structures & big-integers — recursion, heaps, carry chains

17. ~~**Sorting race** — animate quicksort vs heapsort vs mergesort of a bar array. *Stresses:* recursion (soft
    stack / frame ABI), compares, in-place swaps. *Shows:* bars sorting in real time.~~
    ✓ [/snes/sort-race/](https://biohack.net/snes/sort-race/) *(recursive quicksort + mergesort are the soft-stack
    witness; iterative heapsort is the non-recursive contrast — bsnes-jg PASS `0xB28F`.)*
18. ~~**Maze generate + solve** — recursive-division carve (recursion) then A* (priority-queue heap frontier).
    *Stresses:* recursion + a heap/queue data structure + array. *Shows:* maze built, then the shortest path lit.~~
    ✓ [/snes/maze/](https://biohack.net/snes/maze/) *(carve = recursive **division**, not a backtracker DFS — the
    65816's 256-byte hardware stack can't hold a DFS's O(N) recursion depth; recursive division is ~log depth.)*
19. ~~**π — spigot digits + Monte-Carlo** — unbounded spigot (big-int mul/div/mod) alongside a Buffon/dart
    estimate. *Stresses:* multi-precision **carry chains** + div/mod + rng. *Shows:* digits ticking out beside
    a dart scatter with the running estimate.~~ ✓ [/snes/spigot/](https://biohack.net/snes/spigot/)
20. ~~**Bignum factorial / Fibonacci** — `1000!` or `Fib(5000)` in a digit array, schoolbook carry mul/add.
    *Stresses:* multi-precision **carry propagation** across arrays. *Shows:* the giant number filling the
    screen + its digit count.~~ ✓ [/snes/factorial/](https://biohack.net/snes/factorial/)

---

## Coverage map (why this is a good battery, not 20 of the same test)

<!-- NOTE TO SELF (strikethrough): cross out completed items EVERYWHERE in this doc, consistently — same as
     the ideas list at the top. In this coverage map: strike each demo number (~~N~~) when its demo ships, and
     strike the left-column aspect name once EVERY number in that row is crossed off. All 20 shipped → the
     whole table is struck. Strikethrough = done; do not leave completed items plain. -->
| Codegen aspect | Demos |
|---|---|
| ~~complex / 32-bit fixed-point **multiply**~~ | ~~1~~, ~~2~~, ~~3~~, ~~4~~, ~~8~~, ~~9~~–~~10~~, ~~11~~, ~~13~~, ~~16~~ |
| ~~**division** / reciprocal / sqrt~~ | ~~2~~, ~~13~~, ~~15~~, ~~16~~, ~~19~~ |
| ~~**recursion** & the soft stack / frame ABI~~ | ~~17~~, ~~18~~ |
| ~~**heaps / queues / structs** (data structures)~~ | ~~18~~ |
| ~~**bit manipulation** (pack/shift/boolean)~~ | ~~5~~, ~~6~~ |
| ~~multi-precision **carry-chain** codegen~~ | ~~19~~, ~~20~~ |
| ~~**shift-add**, multiply-free~~ | ~~12~~ |
| ~~**far / high-WRAM** buffers (a16-only)~~ | ~~1~~, ~~4~~, ~~8~~, ~~13~~ |
| ~~**PRNG + scatter** writes~~ | ~~4~~, ~~7~~, ~~19~~ |
| ~~**sin/cos LUT** indexing~~ | ~~9~~, ~~10~~, ~~11~~, ~~14~~, ~~16~~ |

## Recommended first picks

Sharpest compiler stress for the effort, each hitting a corner the existing demos don't:

- ~~**#2 Newton's-method fractal** — complex **division** per pixel (Mandelbrot is multiply-only).~~ ✓ [/snes/newton/](https://biohack.net/snes/newton/)
- ~~**#16 wireframe 3-D solid** — matrix multiply + perspective **divide** + line rasterisation.~~ ✓ [/snes/3d-wireframe/](https://biohack.net/snes/3d-wireframe/)
- ~~**#19 π — spigot digits + Monte-Carlo** — multi-precision **carry-chain** codegen + div/mod + rng.~~ ✓ [/snes/spigot/](https://biohack.net/snes/spigot/)
- ~~**#20 Bignum factorial / Fibonacci** — multi-precision **carry-chain** codegen, untouched by every other demo.~~ ✓ [/snes/factorial/](https://biohack.net/snes/factorial/)
- ~~**#12 CORDIC** — a **multiply-free** shift-add inner loop (and the repo already has CORDIC tables).~~ ✓ [/snes/cordic/](https://biohack.net/snes/cordic/)

Each would be built on `snesgfx` the same way as Space Invaders: a shared host+target logic header, a
`dev/run.sh <name>` differential gate, and a two-emulator screenshot.

---

# Round 2 (#21+) — new codegen corners

Round 1's 20 demos lean almost entirely on **fixed-point integer math** (Q-format multiply, carry chains,
div/mod, sin/cos LUTs). The bugs they surfaced all lived in *libcall and ABI* paths — so Round 2 deliberately
targets the codegen families the first 20 **never execute**. Same bar as Round 1 (shared host+target header,
differential CRC, `snesgfx` render); the table below tracks the **new** corners each opens.

## Untested-corner coverage map (the point of Round 2)

| New codegen corner | Why bugs hide there | Demos |
|---|---|---|
| ~~**soft-float (IEEE-754)**~~ — `__addsf3`/`__mulsf3`/`__divsf3`/`__ltsf2`/`__floatsisf`/`__fixsfsi` | no Round-1 demo uses `float` at all; single-precision is fully specified → bit-exact differential | ~~21~~, ~~24~~ |
| ~~**64-bit integers**~~ — `__muldi3`/`__udivdi3`/`__ashldi3`/`__lshrdi3`, 4-limb carry | every Round-1 demo tops out at 32-bit | ~~22~~ |
| ~~**jump-table / computed branch** — switch-dispatch + indirect-call tables~~ | never exercised | ~~29a~~ |
| ~~**aggregate / by-value struct ABI**~~ — sret vs register-pair return | structs exist (#18) but are never passed/returned **by value** | ~~26~~ |
| ~~**bitfield insert/extract**~~ — `unsigned x : n` fields | zero usage so far | ~~29b~~ |
| ~~**variable-count shifts** — `__ashlsi3`/`__lshrsi3` with a *data-dependent* count~~ | all Round-1 shifts are compile-time constants | ~~28~~, ~~30~~ |
| ~~**variadic `va_arg`** — the stack-walking calling convention~~ | untouched | ~~32~~ |
| ~~**string / char-array building**~~ — `memcpy`/`memmove`/`strlen` over grown buffers | untouched | ~~23~~, ~~24~~ |
| ~~**pointer-chasing dynamic trees** — recursive build/walk over pooled nodes~~ | #18's heap is a flat array, not a linked structure | ~~31~~ |
| ~~**modulo-heavy** inner loop — `__umodhi`/`__umodsi3` per iteration~~ | div appears, but never `%` as the hot op | ~~27~~ |
| ~~**bit-reversal / interleave permutation**~~ | never exercised | ~~25~~, ~~28~~ |

## Highest bug-yield — brand-new libcall/ABI paths

21. ~~**Soft-float Mandelbrot / plasma (IEEE-754)** — render in `float` instead of fixed-point. *Stresses:* the
    **entire soft-float library**. The differential is razor-sharp — single precision is fully specified, so
    host `float` must equal target soft-float **bit-for-bit**; any rounding/conversion bug shows instantly.
    *Shows:* the fractal, with a fixed-point twin for the timing contrast. ← **sharpest first pick.**~~ ✓ [/snes/mandel-float/](https://biohack.net/snes/mandel-float/) *(bit-exact host==default==a16==xy16 `0x4169`; no compiler bug — soft-float codegen correct across all modes)*
22. ~~**64-bit hash plasma / xorshift64 field** — `__muldi3`, 64-bit shifts/xor, carry across 4 limbs.
    *Shows:* an avalanche field (flip one input bit → output bits cascade) or a hash-coloured plasma.
    *(Variant: Q16.48 **deep-zoom** Mandelbrot whose multiply needs a 64-bit intermediate.)*~~ ✓ [/snes/avalanche/](https://biohack.net/snes/avalanche/) *(splitmix64 matrix; bit-exact host==default==a16==xy16 `0x27EA`; disasm `__muldi3`+`__udivdi3`+64-bit shift; no bug)*
26. ~~**Boids flocking (struct-by-value vectors)** — steering functions take/return `vec2` **by value**.
    *Stresses:* the **aggregate-return ABI** (sret vs register pair), invoked thousands of times/frame.
    *Shows:* a flock swirling — separation / alignment / cohesion.~~ ✓ [/snes/boids/](https://biohack.net/snes/boids/) *(vec2 by-value kernel, noinline; bit-exact host==default==a16==xy16 `0xA8AB`; disasm by-value-calls=497 + `__mulsi3` + `__divsi3`; no bug — aggregate-return ABI correct in all modes)*
29a. ~~**Bytecode-VM turtle** — a stack machine interpreting a compiled program. *Stresses:* **jump-table
    dispatch** + a function-pointer opcode table. *Shows:* turtle graphics driven by bytecode.~~ ✓ [/snes/turtle-vm/](https://biohack.net/snes/turtle-vm/) *(dense switch → `JMP (abs,X)` jump table + `jsr __call_indir` fnptr opcode table; bit-exact host==default==a16==xy16 `0x4007`; no bug — confirms the xy16 JMPIdxIndir hardening)*
~~32. **printf HUD (variadic)** — a tiny `vsnprintf` driving a readout; exercises **`va_arg`**. Best *folded
    into* another demo's HUD rather than built standalone.

## Strong stressors with great visuals

~~23. **L-system turtle** — string rewriting (char-array grow, `memmove`) + bracket **push/pop** of turtle
    state + sin/cos. *Shows:* Koch / dragon curve / algorithmic plant growing.~~ ✓ [/snes/lsystem/](https://biohack.net/snes/lsystem/)
24. ~~**Recursive-descent function plotter** — a real **recursive-descent parser** (deep recursion + string
    scan) feeding a switch-dispatch evaluator; pairs with soft-float (#21) for the eval. *Shows:* type-in
    `y=f(x)` plotted live.~~ ✓ [/snes/fn-plot/](https://biohack.net/snes/fn-plot/)
~~25. **Radix-2 FFT spectrum analyser** — **bit-reversal permutation** + in-place butterfly loops + twiddle
    complex-multiply. *Shows:* animated frequency bars of a synthesised chord.~~ ✓ [/snes/fft/](https://biohack.net/snes/fft/)
~~27. **Times-table cardioid** — `(k·i) mod N` per chord around a circle, animated `k`; **modulo-heavy** inner
    loop. *Shows:* the morphing cardioid / nephroid envelope.~~ ✓ [/snes/cardioid/](https://biohack.net/snes/cardioid/)
~~28. **Hilbert / Gray-code curve** — bit-interleave + **variable-count** shifts/rotates + recursion.
    *Shows:* the space-filling curve at rising order.~~ ✓ [/snes/hilbert/](https://biohack.net/snes/hilbert/)
29b. ~~**Truchet tiles (packed bitfields)** — per-cell state as `unsigned : n` bitfields; stresses
    insert/extract. *Shows:* a curved-tile labyrinth.~~ ✓ [/snes/truchet/](https://biohack.net/snes/truchet/) *(16-bit bitfield struct, 6 fields; bit-exact host==default==a16==xy16 `0xB3E6`; disasm and/ora/shift, libcalls=0; no bug)*
~~30. **TEA / XTEA cipher avalanche** — tight 32-bit mix (data-dependent shifts + adds + xor + magic delta).
    *Shows:* encrypt the framebuffer; one bit flip → avalanche.~~ ✓ [/snes/tea/](https://biohack.net/snes/tea/)
~~31. **Barnes-Hut quadtree galaxy** — recursive build/walk over a **pooled struct-node tree** (distinct from
    #13's flat-array N-body). *Shows:* a galaxy with the quadtree overlaid.~~ ✓ [/snes/bhut/](https://biohack.net/snes/bhut/)

## Round 2 first picks

Sharpest at opening a code path the first 20 never run:

- ~~**#21 soft-float** — largest untested surface, and a bit-exact differential.~~ ✓ [/snes/mandel-float/](https://biohack.net/snes/mandel-float/)
- ~~**#22 64-bit integers** — `__muldi3` & friends, never touched.~~ ✓ [/snes/avalanche/](https://biohack.net/snes/avalanche/)
- ~~**#26 struct-by-value ABI** — aggregate return on a hot path.~~ ✓ [/snes/boids/](https://biohack.net/snes/boids/)
- ~~**#29a jump-table VM** — indirect dispatch / function-pointer table.~~ ✓ [/snes/turtle-vm/](https://biohack.net/snes/turtle-vm/)

---

# Round 3 (#33–#52) — twenty more new codegen corners

Rounds 1–2 (32 demos) exhausted fixed-point integer math, 32-bit `float`, 64-bit *unsigned* integers,
the dense jump-table, struct-by-value, clean bitfields, variable shifts, variadics, string libcalls,
pointer-trees, and the far-pointer path. Round 3 targets **twenty corners none of the first 32 execute** —
the rest of the floating-point library (`double` + libm), the non-local-control-flow family
(`setjmp`/`longjmp`, computed-`goto`, Duff's device), dynamic stack frames (`alloca`/VLA), the
allocator/ABI edges (free-list, `qsort` callback, 8+-arg spill, union punning), the *signed* and
*constant-divisor* arithmetic paths, recursive DSP feedback, and decode/refinement loops. Same bar as
before: a shared host+target header, a differential CRC, a `snesgfx` render, the picture *is* the proof.

**Two design gotchas to honour up front** (the "measure, don't assume" rule):

- **libm transcendentals are NOT bit-exact across libms.** IEEE-754 mandates correct rounding only for
  `+ − × ÷` **and `sqrtf`**; `sinf`/`cosf`/`expf`/`logf`/`powf`/`atan2f` may differ by 1 ULP between the
  host's glibc and the target's picolibc — so a naive `host == target` CRC over those would FAIL even
  with *correct* codegen. A libm demo must either (a) restrict the differential to `sqrtf` + plain float
  arithmetic, or (b) ship its **own** polynomial/CORDIC transcendental in the shared header (host==target
  by construction, like the existing `SINCOS` LUT). Pick one deliberately; don't oracle against glibc's
  `sinf`. `double` *arithmetic* (`__adddf3`/`__muldf3`/`__divdf3`, +`sqrt`) **is** correctly-rounded → a
  clean bit-exact differential, same as #21 for `float`.
- **`setjmp`/`longjmp` and `alloca`/VLA may not be fully supported** by the llvm-mos soft-stack target.
  That is itself a finding worth surfacing — but for a shippable *demo*, verify the toolchain provides
  them first; if a feature is absent or miscompiles, that becomes a backend bug report, not a demo.

## Untested-corner coverage map (the point of Round 3)

| New codegen corner | Why bugs hide there | Demos |
|---|---|---|
| **`double` soft-float** — `__adddf3`/`__muldf3`/`__divdf3`/`__fixdfsi`/`__floatsidf`/`__extenddfsf2`/`__truncdfsf2` | #21/#24 used only 32-bit `float`; `double` is a wholly separate 64-bit library, correctly-rounded → bit-exact | ~~33~~ |
| **libm transcendentals** — `sqrtf` (+ self-shipped `sin`/`exp`) | #24 used float *operators*, never a libm *function* call (see the ULP gotcha above) | 34 |
| **non-local jumps** — `setjmp`/`longjmp` full context save/restore | the whole register + SP + return-addr context spill; never exercised | 35 |
| ~~**dynamic stack frames** — `alloca` / C99 VLAs (runtime-sized frame)~~ | ~~every frame so far is fixed-size; runtime SP adjustment is untested~~ | ~~36~~ |
| ~~**sparse-switch binary search** — if-else comparison tree, *not* a jump table~~ | ~~#29a was a *dense* switch → table; non-contiguous cases lower totally differently~~ | ~~37~~ |
| **computed `goto` / label values** — `goto *tab[op]` threaded dispatch | distinct from #29a's switch jump-table; the threaded-code path | ~~38~~ |
| ~~**constant-divisor strength reduction** — `/10`,`/60`,`/360` → magic-number multiply-high + shift~~ | ~~#27 was a *runtime* divisor (libcall); constant divisors trigger a different optimisation~~ | ~~39~~ (FINDING: llvm-mos does NOT strength-reduce — retains `__udivNi3`, correct on soft-multiply) |
| ~~**table-indexed ROM-LUT byte loop** — 256-entry `const` table, long-addressed per byte~~ | ~~reads a big `const` table from ROM via 24-bit addressing every iteration~~ | ~~40~~ |
| ~~**free-list allocator** — manual malloc/free, pointer recycling~~ | ~~#31's pool is append-only (bump + reset); a free list recycles individual nodes~~ | ~~41~~ ✓ [/snes/poolfx/](https://biohack.net/snes/poolfx/) |
| ~~**irreducible control flow** — Duff's device (switch jumping into a loop)~~ | ~~a CFG the structurizer can't reduce; never exercised~~ | ~~42~~ ✓ [/snes/duff/](https://biohack.net/snes/duff/) |
| ~~**signed 64-bit divide/mod** — `__divdi3`/`__moddi3` (sign-corrected)~~ | ~~#22 was *unsigned* 64-bit; signed div/mod is a distinct sign-handling libcall~~ | ~~43~~ ✓ [/snes/sodo/](https://biohack.net/snes/sodo/) (fires as combined `__divmoddi4`) |
| **overflow-checked / saturating arithmetic** — `__builtin_add_overflow`, carry/V-flag tests + clamp | flag-testing add/sub sequences never stressed | ~~44~~ |
| ~~**union type-punning** — `union{float;uint32}` aliased load/store, bit reinterpret~~ | ~~reading one storage as two types — the aliasing/reinterpret path~~ | ~~45~~ ✓ [/snes/metaball/](https://biohack.net/snes/metaball/) |
| ~~**indirect comparator ABI** — `qsort` with a function-pointer comparator callback~~ | ~~#17's sorts were hand-written; libc `qsort` calls *back* per compare~~ | ~~46~~ ✓ [/snes/qsortviz/](https://biohack.net/snes/qsortviz/) **🐞 caught+fixed `G_SCMP` backend crash** |
| ~~**iterative refinement** — Newton-Raphson reciprocal/sqrt (1/z, isqrt)~~ | ~~a convergent fixed-point loop, distinct from a single divide libcall~~ | ~~47~~ ✓ [/snes/nrecip/](https://biohack.net/snes/nrecip/) |
| **recursive feedback (IIR)** — `y[n]=a·y[n−1]+b·y[n−2]+x[n]` dependency chain | #25's FFT is feed-forward + reorderable; an IIR feedback chain can't be reordered | ~~48~~ |
| ~~**decode state machine + back-reference** — RLE/LZ decompression with output copy-back~~ | ~~a byte-stream decoder writing back-references into its own output (pointer arith)~~ | ~~49~~ ✓ [/snes/lzdec/](https://biohack.net/snes/lzdec/) |
| ~~**>register-count argument spill** — functions with 8+ params passed on the soft stack~~ | ~~every prior call fits the register-arg budget; argument spilling is untested~~ | ~~50~~ ✓ [/snes/cgrade/](https://biohack.net/snes/cgrade/) |
| ~~**resumable functions** — coroutine/protothread static-state switch (cooperative tasks)~~ | ~~local state preserved across re-entry via a saved case index~~ | ~~51~~ ✓ [/snes/critters/](https://biohack.net/snes/critters/) |
| ~~**cross-byte-boundary bitfields** — `uint32_t a:5,b:11,c:7,d:9` straddling bytes~~ | ~~#29b's fields fit one `uint16`; straddling fields force multi-byte shift + mask~~ | ~~52~~ ✓ [/snes/disbits/](https://biohack.net/snes/disbits/) |

## The twenty (each opens a corner the first 32 never run)

33. ~~**Deep-zoom Mandelbrot — `double` precision.** Render the escape-time iteration in **64-bit `double`**
    beside a 32-bit `float` twin; as the zoom deepens the `float` side pixelates into blocks while `double`
    stays crisp. *Stresses:* the entire **double-precision soft-float library**
    (`__muldf3`/`__divdf3`/`__adddf3`/`__fixdfsi`/`__floatsidf`/`__extenddfsf2`/`__truncdfsf2`). Bit-exact
    differential — IEEE-754 `double` arithmetic is correctly rounded. *Shows:* a live zoom with a
    float-vs-double split screen (the precision cliff is the visual).~~ ✓ [/snes/mandel-double/](https://biohack.net/snes/mandel-double/) — bit-exact `host==default==a16==xy16==0x0EDF`; double top / float bottom (whole set, seamless), cliff folded into the gate + shown host-side (deep zoom too slow live); NEW 3rd witness of the `a16-rc-undef-ra-pure-virtual` known issue (code bit-exact correct). ([plan](../plans/2026-06-30-33-snes-mandel-double.md))

34. **Function-surface ripple — `sqrtf` + libm.** A rotating height-shaded plot of
    `z = ownsin(ownsqrt(x²+y²) − t)`, or an accurate pendulum. *Stresses:* a real **libm `sqrtf` call**
    (correctly-rounded → differentiable) plus the float arithmetic around it; the trig comes from a
    **header-shipped polynomial/CORDIC `sin`** so host==target by construction (see the ULP gotcha).
    *Shows:* a breathing 3-D ripple surface.

35. **Backtracking solver — `setjmp`/`longjmp`.** An N-Queens or maze solver that places pieces recursively
    and **`longjmp`s straight back to the last choice point** on a dead end. *Stresses:* **non-local-jump
    context save/restore** (`setjmp`/`longjmp` — full SP + return + callee-saved spill); verify toolchain
    support first. *Shows:* the board filling, then snapping back as it backtracks, live.
    **⚠ BLOCKED (2026-06-30) — `longjmp` is BROKEN on the 65816.** Scoping this demo surfaced a real bug:
    the SDK's common `setjmp.S` is 6502-only — it saves/restores only the **8-bit page-$0100 hardware
    stack**, but the 65816 native-mode stack pointer is **16-bit**, so `longjmp` corrupts S and `rts`-es to
    garbage (`setjmp` + normal return works; `longjmp` never returns). Fails in **default-8-bit AND
    `+mos-a16`** → pre-existing upstream `llvm-mos-sdk`, not the #321 fork. The "gap is a finding" outcome
    idea #35 itself anticipated. Demo deferred until a 65816-aware `setjmp.S` lands (16-bit `tsc`/`tcs` +
    stack-relative return addr). Full repro + root cause:
    [investigation](2026-06-30-setjmp-longjmp-65816-native-stack-bug.md); queued in
    [upstream-contribution-status](../upstream-contribution-status.md).

36. ~~**Polygon scanline fill — `alloca` / VLA.** Spinning convex/concave polygons of varying vertex counts,
    each filled with an **edge table sized at runtime** (`int xs[nverts]`). *Stresses:* **dynamic stack
    allocation** (`alloca`/VLA → runtime frame-pointer adjustment); a soft-stack target may not support it
    — a gap is a finding. *Shows:* morphing filled polygons (3→12 sides) tumbling.~~ ✓ [/snes/polyfill/](https://biohack.net/snes/polyfill/) — a tumbling star morphs its point count (3→8) driving a runtime-sized VLA crossing table (`int16_t xs[nv]`) in an even-odd scanline fill; `host==default==+mos-a16==+mos-xy16==0x8ED9` on bsnes-jg, `-verify` clean ×3. **No compiler bug** — the soft-stack target lowers C99 VLAs (runtime SP adjustment) correctly; "the gap" idea #36 anticipated does not exist.

37. ~~**CHIP-8 / step-sequencer — sparse switch.** An opcode interpreter whose cases are **non-contiguous**
    (`0x00E0`, `0x1NNN`, `0xANNN`, `0xFX55`…), forcing a **binary-search if-else tree** instead of #29a's
    dense jump table. *Stresses:* **sparse-switch comparison-tree lowering**. *Shows:* a tiny CHIP-8 game
    or a step-sequenced light show running its own bytecode.~~ ✓ [/snes/seqvm/](https://biohack.net/snes/seqvm/) — a register VM with 14 non-contiguous opcodes (`0x00..0xF0`) drives an 8-bar equalizer; `switch(op)` lowers to a **comparison tree** (compares=22, indexed-indirect jmp=0 — not a table/computed-goto); `host==default==+mos-a16==+mos-xy16==0xE8C5` on bsnes-jg, `-verify` clean ×3. **No compiler bug.**

38. ~~**Threaded-code VM — computed `goto`.** A Brainfuck/Forth interpreter dispatching with
    **`goto *handlers[op]`** (label-as-value threading) — the fastest interpreter loop, a different path
    than a `switch`. *Stresses:* **indirect-goto / label-value dispatch**. *Shows:* a Brainfuck program
    drawing a pattern as its tape head scrubs.~~ ✓ [/snes/bf-vm/](https://biohack.net/snes/bf-vm/) — Hello World; `goto *handlers[op]` → 65816 indexed-indirect `jmp ($ind,x)`; `host==default==a16==xy16==0x9954` on bsnes-jg, `-verify` clean ×3. **No compiler bug** — `indirectbr`/`blockaddress` lower correctly across all modes.

39. ~~**Analog clock + odometer — constant-divisor magic reciprocal.** Split seconds/minutes/hours and base-N
    digits with **compile-time constant divides** (`/60`, `/12`, `/10`, `/360`). *Stresses:* the
    compiler's **strength-reduction of constant division to a magic-number multiply-high + shift** (distinct
    from #27's runtime `__umodsi3`). *Shows:* a sweeping clock face + a rolling base-N odometer.~~ ✓ [/snes/divclock/](https://biohack.net/snes/divclock/) — sweeping analog clock + rolling odometer; `host==default==+mos-a16==+mos-xy16==0xF72E` on bsnes-jg, `-verify` clean ×3. **MEASURED FINDING (no bug):** llvm-mos does **not** strength-reduce constant division to a magic reciprocal at any width (even `uint16 x/10`→`__udivhi3`) — the reciprocal needs a `MULHU` that is itself a libcall on this soft-multiply target, so the cost model correctly retains `__udivNi3`. The demo thus stresses heavy constant-divisor division, proven bit-exact across all modes.

40. ~~**Procedural hash-texture — table-driven CRC32.** Feed coordinates through a **real CRC32 with a
    256-entry `const` table in ROM** (a 24-bit-addressed indexed load per byte) to colour a scrolling,
    mutating field. *Stresses:* a **256-entry ROM-LUT indexed byte loop**. *Shows:* "checksum rain" /
    hash-marble that flows.~~ ✓ [/snes/crctex/](https://biohack.net/snes/crctex/) — bit-standard CRC-32 (poly 0xEDB88320, `crc32("123456789")==0xCBF43926`), a `const uint32[256]` ROM table indexed per byte colours a flowing hash-marble field; `host==default==+mos-a16==+mos-xy16==0xDBBA` on bsnes-jg, `-verify` clean ×3. **No compiler bug** — the ROM-LUT indexed byte loop is byte-exact across all modes.

41. ~~**Particle fountain — free-list pool allocator.** Particles **allocated on spawn and freed on death**,
    recycling slots through a manual **free list** (distinct from #31's append-only bump pool). *Stresses:*
    **free-list pointer recycling / manual malloc-free**. *Shows:* a sparking fountain with particles
    continuously born and dying.~~ ✓ [/snes/poolfx/](https://biohack.net/snes/poolfx/) *(free-list LIFO recycle of 48 slots; bit-exact host==default==a16==xy16 `0x2B9B`; ldy-indexed slot chase, 0 arith libcalls; no bug)*

42. ~~**Dissolve transition — Duff's device.** A screen wipe/dissolve copy unrolled with the classic
    **switch-jumping-into-a-loop**. *Stresses:* **irreducible loop-switch control flow** the structurizer
    can't reduce. *Shows:* one image dissolving into the next in interleaved bursts.~~ ✓ [/snes/duff/](https://biohack.net/snes/duff/) *(Duff's device copy, lengths 1..40; bit-exact host==default==a16==xy16 `0x5531`; jmp=19 branch mesh, 0 arith libcalls; no bug — backend lowers irreducible CFG cleanly)*

43. ~~**Light-years odometer / 64-bit Julia — signed 64-bit divide.** A Q-format orbit or a giant signed
    counter needing **`__divdi3`/`__moddi3`** (signed 64-bit divide+mod), distinct from #22's unsigned
    `__udivdi3`. *Stresses:* **signed 64-bit division/modulo** (sign-correction codegen). *Shows:* a vast
    signed odometer ticking through zero, or a 64-bit-deep Julia.~~ ✓ [/snes/sodo/](https://biohack.net/snes/sodo/) *(signed odometer through zero, `v%10`/`v/=10`; bit-exact host==default==a16==xy16 `0xD2A2`; clang merges div+mod into the combined SIGNED `__divmoddi4`, unsigned-64=0; no bug)*

44. ~~**HDR light blending — saturating / overflow-checked add.** Many overlapping translucent glows summed
    per pixel with **`__builtin_add_overflow` saturation** (clamp to white). *Stresses:*
    **overflow-builtin / carry-and-V-flag saturating arithmetic**. *Shows:* drifting bloom-lights that
    blow out to white where they pile up.~~ ✓ [/snes/hdr-bloom/](https://biohack.net/snes/hdr-bloom/) — 6 glows sat-added per cell (`__builtin_add_overflow`→`adc`+`bcs`); overlaps clamp to white; `host==default==a16==xy16==0xF951` on bsnes-jg, `-verify` clean ×3. **No compiler bug.**

45. ~~**Metaballs — union type-pun fast-inverse-sqrt.** The Quake `union { float f; uint32_t i; }`
    **bit-hack reciprocal-sqrt** drives a field of merging blobs. *Stresses:* **union type-punning**
    (aliased load/store + float↔int bit reinterpret). *Shows:* gooey metaballs splitting and fusing.~~ ✓ [/snes/metaball/](https://biohack.net/snes/metaball/) *(Quake fast-inverse-sqrt, magic `0x5f3759df`; bit-exact host==default==a16==xy16 `0xAEBE`; `__mulsf3`+magic-byte immediates, one-op-per-statement soft-float; no bug)*

46. ~~**Sort visualizer — `qsort` + comparator callback.** Bars sorted by **libc `qsort` with a swappable
    function-pointer comparator** (by height / hue / parity) — an **indirect call per comparison**.
    *Stresses:* the **`qsort` callback / indirect-comparator ABI**. *Shows:* the array animating as
    different comparators reshuffle it.~~ ✓ [/snes/qsortviz/](https://biohack.net/snes/qsortviz/) **🐞 CAUGHT + FIXED A REAL BACKEND BUG** — the `(x>y)-(x<y)` comparator emits `G_SCMP`, which the mos legalizer couldn't lower (backend abort in default/a16/xy16 alike); fix = `G_SCMP`/`G_UCMP` `.lower()` (patch `0016`), queued upstream. Post-fix bit-exact host==default==a16==xy16 `0x8EA5`.

47. ~~**Perspective floor/tunnel — Newton-Raphson reciprocal.** A textured ground plane computing **`1/z`
    per span by iterative Newton refinement** (no hardware divide). *Stresses:* **iterative fixed-point
    refinement** (a convergent reciprocal/sqrt loop). *Shows:* a racing perspective-mapped checker floor
    or tunnel.~~ ✓ [/snes/nrecip/](https://biohack.net/snes/nrecip/) *(multiply-only Newton reciprocal `x=x*(2-m*x)`, Q15/Q16; bit-exact host==default==a16==xy16 `0x044A`; `__mulsi3`=6, divide-libcalls=0; no bug)*

48. ~~**Resonant-filter scope — IIR / Goertzel feedback.** A 2-pole **IIR resonator**
    (`y[n] = a·y[n−1] − b·y[n−2] + x[n]`) ringing on an impulse, or a Goertzel tone detector. *Stresses:*
    the **recursive feedback dependency chain** (can't be reordered like #25's feed-forward FFT). *Shows:*
    an oscilloscope of a plucked, decaying resonance; or frequency bins lighting to a tune.~~ ✓ [/snes/iir-scope/](https://biohack.net/snes/iir-scope/) — 4 plucked 2-pole resonators; `host==default==a16==xy16==0x49BD` on bsnes-jg, `__mulsi3=2`, `-verify` clean ×3. **No compiler bug.**

49. ~~**Image-decompress reveal — RLE/LZ back-references.** A compressed picture **decoded by a byte-stream
    state machine that copies back-references from its own output** (LZ77 sliding window). *Stresses:* the
    **decode state machine + output back-reference pointer arithmetic**. *Shows:* the classic "image
    loading in" progressive reveal.~~ ✓ [/snes/lzdec/](https://biohack.net/snes/lzdec/) *(LZSS decoder, overlapping back-refs; 56B→256-cell diamond; bit-exact host==default==a16==xy16 `0x0100`; indirect `lda ($zp)` copy, 0 libcalls; no bug)*

50. ~~**Color-grade kernel — many-argument calling convention.** A per-pixel transform taking **8+
    coefficients** (lift/gamma/gain ×3 + mix), forcing arguments **onto the soft stack**. *Stresses:*
    **>register-count argument spilling** in the calling convention. *Shows:* a live scene re-grade
    sweeping through looks.~~ ✓ [/snes/cgrade/](https://biohack.net/snes/cgrade/) *(10-int16-arg `color_grade`, extras spill to `.noinit..Lstatic_stack`; bit-exact host==default==a16==xy16 `0x783F`; no bug)*

51. ~~**Cooperative critters — coroutines / protothreads.** Dozens of agents, each a **resumable
    switch-state function** (protothread) that yields and resumes, preserving local state across frames.
    *Stresses:* **resumable-function state preservation** (saved case-index re-entry). *Shows:* a swarm of
    little creatures each running its own scripted behaviour concurrently.~~ ✓ [/snes/critters/](https://biohack.net/snes/critters/) *(24 protothreads, `lc`-dispatch + case-in-loop re-entry + struct-kept state; bit-exact host==default==a16==xy16 `0xAD9F`; no bug)*

52. ~~**Live 65816 disassembler — cross-byte-boundary bitfields.** Decode an opcode byte-stream into
    **bitfields that straddle byte boundaries** (`opcode:8, mode:3, len:2, …` packed across a `uint32_t`),
    forcing multi-byte shift + mask extract (distinct from #29b's single-`uint16` fields). *Stresses:*
    **unaligned / cross-boundary bitfield extract-insert**. *Shows:* a scrolling, colour-coded disassembly
    of its own ROM (meta!).~~ ✓ [/snes/disbits/](https://biohack.net/snes/disbits/) *(uint32 fields `group:5` crosses bit 16, `flags:7` crosses bit 24 → multi-byte shift+mask; bit-exact host==default==a16==xy16 `0x31D7`; and-masks + 23 shifts, 0 libcalls; no bug)*

## Round 3 first picks

Sharpest at opening a code path the first 32 never run:

- ~~**#33 `double` soft-float** — the largest brand-new library surface, with a clean bit-exact differential (the `double` analogue of #21).~~ ✓ [/snes/mandel-double/](https://biohack.net/snes/mandel-double/)
- **#35 `setjmp`/`longjmp`** — the context save/restore ABI; nothing else in 52 demos touches it (and may surface a toolchain gap). **⚠ BLOCKED — it surfaced exactly that gap: `longjmp` is broken on the 65816 (6502-only `setjmp.S`); see #35 above + [investigation](2026-06-30-setjmp-longjmp-65816-native-stack-bug.md).**
- ~~**#38 computed-`goto`** — a second VM that opens the *threaded-dispatch* path #29a's `switch` jump-table didn't.~~ ✓ [/snes/bf-vm/](https://biohack.net/snes/bf-vm/) — clean positive, no bug.
- ~~**#44 saturating / `__builtin_add_overflow`** — flag-sequence codegen, plus a gorgeous additive-bloom visual.~~ ✓ [/snes/hdr-bloom/](https://biohack.net/snes/hdr-bloom/) — clean positive, no bug.
- ~~**#48 IIR feedback** — the non-reorderable recursive dependency chain the feed-forward FFT (#25) never exercised.~~ ✓ [/snes/iir-scope/](https://biohack.net/snes/iir-scope/) — clean positive, no bug.

---

# Round 4 (#53–#72) — twenty more new codegen corners

Rounds 1–3 (52 demos) exhausted fixed-point integer math, single/double soft-float *arithmetic*, un/signed
64-bit integers, the dense **and** sparse switch, computed-`goto`, struct-**by-value** pass, clean **and**
straddling bitfields, variable shifts, variadics, string libcalls, pointer-trees, free-lists, Duff's device,
VLAs, `qsort` callbacks, and the far-pointer path. Round 4 targets **twenty corners none of the first 52
execute** — chosen by walking the backend for opcodes/libcalls the battery has *never* emitted. Each row was
**verified present in `vendor/llvm-mos/` before drafting** (line numbers are `MOSLegalizerInfo.cpp` unless
noted), so these are real paths, not guesses:

- the **bit-population intrinsic family** — count-ones/leading-zeros/trailing-zeros/parity/first-set, i.e.
  `__popcountsi2` / `__clzsi2` / `__ctzsi2` / `__paritysi2` / `__ffssi2` (compiler-rt) *and* the inline
  `G_CTLZ`/`G_CTTZ`/`G_CTPOP` shift-tree lowering (`.lower()` @308) — never once emitted in 52 demos;
- **byte-swap / bit-reverse intrinsics** — `__bswapsi2`, and `G_BITREVERSE.lower()` @186 (clang's
  `__builtin_bswap32` / `__builtin_bitreverse32`), distinct from #25/#28's *hand-rolled* reversal loops;
- **widening multiply-high** — `G_UMULH`/`G_SMULH.lower()` @300 (extend→mul→shift→trunc), the compiler
  recognising `(a*b) >> 16` as a high-half multiply — not the full `__mulsi3` the fixed-point demos forced;
- **branchless min/max/abs** — `G_SMIN`/`G_SMAX`/`G_UMIN`/`G_UMAX.lower()` @272 and `G_ABS.custom()` @281
  (select+icmp, no branch), never the *hot* op before;
- **NaN / unordered float compares** — `__unordsf2` / `__eqsf2` / `__nesf2` (`comparesf2.c`); #21/#33 only
  ever used the *ordered* `<`, never equality or an unordered/NaN test;
- **64-bit⇄float conversion** — `__floatdidf` / `__fixdfdi` / `__floatdisf` / `__fixsfdi`; the float demos
  never converted a 64-bit integer to/from floating point;
- the libc **`div()` / `ldiv()`** returning **`div_t` by value** — hitting the aggregate-return ABI *and*
  the custom `G_SDIVREM` legalizer's stack-temp path (@229, `legalizeDivRem`) at once, distinct from #39/#43
  which used the raw `/` and `%` operators separately;

…plus data-structure / algorithm corners the battery never ran (union-find path compression, Fenwick `i&-i`,
non-comparison sort, convex-hull orientation, 2-D DP tables, Huffman bit-tree decode) and rendering
techniques with distinct codegen (widening-mul rotozoom, barycentric edge-function fill, error diffusion,
marching squares, gradient noise, 3-D multi-dim indexing). Same bar as before: a shared host+target header,
a differential CRC, a `snesgfx` render, the picture *is* the proof.

**Three design gotchas to honour up front** (the "measure, don't assume" rule, Round-4 edition):

- **Keep the differential integer or integer-exact wherever possible.** Corners 53–57, 60–72 are integer /
  fixed-point → host==target is bit-exact by construction. The three float corners (58/59 + any float used
  elsewhere) stay differential-safe only if (a) you use **float *arithmetic* + header-shipped polynomials**,
  **never glibc libm** (the Round-3 ULP gotcha still holds — no `sinf`/`expf` oracle), and (b) IEEE
  conversions/`sqrtf` are correctly-rounded so they *are* safe.
- **Do not fold raw NaN bit-patterns into the CRC (#58).** A quiet-NaN payload is not fully specified, so
  hashing raw NaN bits could diverge even with correct codegen. Fold the **branch outcome** (`isnan(x)` →
  the *colour index* chosen for a singularity), not the float's bits — the boolean is deterministic and
  host==target. This keeps the demo a test of the *unordered-compare codegen*, not of NaN payloads.
- **`div()`/`ldiv()` come from picolibc, `__builtin_bitreverse`/`__builtin_bswap` from clang.** Both are
  confirmed present, but include the right header (`<stdlib.h>`) / use the builtin form so the intended
  `G_SDIVREM` / `G_BITREVERSE` / `__bswapsi2` path is actually taken (a hand-rolled loop would test nothing
  new — that's exactly the #25/#28 vs #54 distinction).

## Untested-corner coverage map (the point of Round 4)

| New codegen corner | Why bugs hide there | Demos |
|---|---|---|
| **bit-population intrinsics** — `__popcountsi2`/`__clzsi2`/`__ctzsi2`/`__paritysi2`/`__ffssi2` + inline `G_CTPOP`/`G_CTLZ`/`G_CTTZ` shift-tree (`.lower()` @308) | never emitted once in 52 demos; the inline lowering is a multi-branch shift sequence with its own edge cases (zero-input, width) | ~~53~~ ✓ |
| **byte-swap / bit-reverse intrinsics** — `__bswapsi2`; `G_BITREVERSE.lower()` @186 | #25/#28 reversed bits by *hand*; the clang builtin → generic-opcode → lowering path is untested | ~~54~~ ✓ |
| **finite-field GF(2⁸) / carryless multiply** — XOR-accumulate + log/antilog table, no carry | a whole ALU profile with **no `adc` carry chain** — pure XOR + table; never exercised | ~~55~~ ✓ |
| **widening multiply-high** — `G_UMULH`/`G_SMULH.lower()` @300 (`(a*b)>>16` recognised) | fixed-point demos forced full `__mulsi3`; the *high-half* recognition + its extend/trunc is a distinct path | ~~56~~ ✓ |
| **branchless min/max/abs** — `G_SMIN`/`G_SMAX`/`G_UMIN`/`G_UMAX.lower()` @272, `G_ABS.custom()` @281 | select+icmp lowering as the **hot** op (sorting network / clamp); #44 was carry/V-flag, not select | ~~57~~ ✓ |
| **NaN / unordered float compares** — `__unordsf2`/`__eqsf2`/`__nesf2` | #21/#33 used only ordered `<`; equality + unordered/NaN tests lower to different libcalls | ~~58~~ ✓ |
| **64-bit⇄float conversion** — `__floatdidf`/`__fixdfdi`/`__floatdisf`/`__fixsfdi` | float demos never converted a 64-bit integer to/from float; a wholly separate conversion libcall set | ~~59~~ ✓ |
| **`div_t` struct-return over custom `G_SDIVREM`** — libc `div()`/`ldiv()` (@229, `legalizeDivRem`) | combines aggregate-return ABI **and** the divrem stack-temp legalizer; #39/#43 used bare `/`,`%` | ~~60~~ ✓ |
| **64-bit modular exponentiation** — `__umoddi3` as the *hot* op in square-and-multiply | #22 was 64-bit mul/shift/xor (hash), #27 was 16/32-bit `%`; a 64-bit `%`-per-iteration loop is neither | ~~61~~ ✓ 🐞 |
| **union-find / disjoint-set** — parent-array **path compression** (in-place pointer rewrite) | #18 (heap), #31 (tree) never did the find-with-compression pointer-chase-and-flatten idiom | ~~62~~ ✓ |
| **Fenwick / binary-indexed tree** — `i & -i` low-bit isolation in a range-sum loop | the `i += i & -i` two's-complement bit trick is a codegen shape nothing else emits | ~~63~~ ✓ |
| **non-comparison sort** — counting/radix: histogram + prefix-sum + scatter, **zero compares** | #17's sorts were all comparison-based; a compare-free scatter sort is a different loop nest | ~~64~~ ✓ |
| **computational-geometry orientation** — cross-product **sign** tests + angular sort (convex hull) | signed 2-D cross products driving branch decisions; never exercised | ~~65~~ ✓ |
| **2-D dynamic-programming table** — memoised recurrence + `max`/`min` reductions + backtrack pointer walk | a doubly-indexed table fill with data-dependent reductions; a new loop/GEP shape | ~~66~~ ✓ |
| **Huffman bit-stream decode** — MSB-first bit reader + pointer-linked tree descent | #49 was *byte*-oriented LZ back-refs; a *bit*-granular reader + tree walk is distinct | ~~67~~ ✓ |
| **gradient (Perlin) noise** — permutation table + fade **polynomial** + gradient dot + lerp | value-noise/plasma/CA never did the perm-index + Hermite-fade + dot-product-of-gradients pipeline | ~~68~~ ✓ |
| **barycentric edge-function raster** — 3 cross-product edge fns + per-pixel interpolation | #16 drew wireframe **lines** only; solid interpolated fill is a different inner loop | ~~69~~ ✓ |
| **error-diffusion (signed spread)** — Floyd–Steinberg propagate signed residual to neighbours + clamp | #7 doom-fire was decay+PRNG; forward-carried *signed* error with saturation is untested | ~~70~~ ✓ |
| **marching-squares contour** — 16-case edge **LUT** + edge-crossing interpolation | #45 rendered the metaball *field*; extracting its iso-contour is a separate case-table + lerp | ~~71~~ ✓ |
| **multi-dimensional array indexing** — true `grid[z][y][x]` with non-pow-2 strides | every prior grid was 1-D or hand-indexed `y*W+x`; compiler-generated N-D GEP multiplies are untested | ~~72~~ ✓ |

## The twenty (each opens a corner the first 52 never run)

### Bit-population, permutation & finite-field ALU — the count/reverse/scan family

53. ~~**Bit-census field — `popcount`/`clz`/`ctz`/`parity`.** Colour each cell by a **bit-population intrinsic**
    of its coordinates and a time term — `popcount(x ^ y ^ t)`, `clz(x | y)`, `ctz(x & y)`, cycling the
    function — producing the famous self-similar XOR/AND bit-fractal, now driven through the *actual*
    intrinsics. *Stresses:* `__popcountsi2` / `__clzsi2` / `__ctzsi2` / `__paritysi2` **and** the inline
    `G_CTPOP`/`G_CTLZ`/`G_CTTZ` shift-tree lowering (`.lower()` @308) at 16- and 32-bit — never emitted in
    52 demos. *Shows:* a breathing, scrolling bit-census texture that morphs as the function cycles.~~ ✓ [/snes/bitcensus/](https://biohack.net/snes/bitcensus/) — bit-exact `host==default==a16==xy16==0x9516`; **MEASURED:** the `ll` builtins **inline-lower** (SWAR masks `#$55`/`#$33` in the disasm), the `__*di2` helpers are never called; clean positive, no bug. Width-safe via the 64-bit `ll` variants. ([plan](../plans/2026-06-30-53-snes-bitcensus.md))

54. ~~**Perfect-shuffle transition — `bswap` + `bit-reverse`.** A screen transition that permutes an image by
    routing each pixel's index through **`__builtin_bswap32` and `__builtin_bitreverse`**, scrambling then
    perfectly un-scrambling it (a radix-reversal / butterfly-network shuffle). *Stresses:* `__bswapsi2` and
    `G_BITREVERSE.lower()` (@186) — the **intrinsic** path, distinct from #25/#28's hand-rolled reversal
    loops. *Shows:* an image dissolving through a digital "riffle shuffle" and snapping back whole.~~ ✓ [/snes/bitshuffle/](https://biohack.net/snes/bitshuffle/) — bit-exact `host==default==a16==xy16==0x2A4A`; bit-reversal is an involution (scramble==unscramble); both builtins **inline-lower** (`G_BITREVERSE` mask-swap cascade `#$aa`/`#$cc`; `bswap32`→byte moves, no `__bswapsi2`). `__builtin_bitreverse` is clang-only → gcc host uses a SWAR reference. Clean positive, no bug. ([plan](../plans/2026-06-30-54-snes-bitshuffle.md))

55. ~~**Reed–Solomon glyph — GF(2⁸) carryless multiply.** Finite-field arithmetic over GF(2⁸) via **log/antilog
    tables and XOR** (Galois multiply, no carry) building a QR-style codeword whose parity symbols repair
    deliberately corrupted cells live. *Stresses:* an ALU profile with **no `adc` carry chain at all** — pure
    XOR-accumulate + ROM-table lookup (Galois `gmul`), a shape nothing in the battery emits. *Shows:* a glyph
    with cells being knocked out and error-corrected back, syndrome bars pulsing.~~ ✓ [/snes/gf256/](https://biohack.net/snes/gf256/) — bit-exact `host==default==a16==xy16==0xC028`; GF(2⁸) `gf_mul` via log/antilog tables + XOR (`GF_EXP`/`GF_LOG` refs, `eor`, **zero mul/div libcalls**), morphing field plaid + live RS syndrome; gate cross-checks `gf_mul` vs a slow bit-by-bit carryless multiply over all 65 536 pairs. Clean positive, no bug. ([plan](../plans/2026-06-30-55-snes-gf256.md))

### Untouched arithmetic-lowering corners

56. ~~**Rotozoom / Droste zoom — widening multiply-high (`G_UMULH`).** A full-screen affine texture spin-zoom
    (rotate + scale a tile) whose sample address is `(coord * scale) >> 16` — a **high-half multiply** of a
    32×32 product. *Stresses:* `G_UMULH`/`G_SMULH.lower()` (@300, extend→mul→shift→trunc), the compiler
    recognising the mul-high instead of forcing a full `__mulsi3`. *Shows:* a hypnotic rotating, pulsing
    zoom of a checker/mandala texture (the classic "rotozoomer").~~ ✓ [/snes/rotozoom/](https://biohack.net/snes/rotozoom/) — bit-exact `host==default==a16==xy16==0x391B`; **MEASURED:** no narrower mul-high exists on this soft-multiply target — the `G_SMULH.lower()` (@300) widens through `__muldi3` (Q16.16) / `__mulsi3` (Q8.8 coeffs), like #39's degrade-to-primitive. Clean positive, no bug. (Heavy gate → snapshot frame 700.) ([plan](../plans/2026-06-30-56-snes-rotozoom.md))

57. ~~**Median denoiser — branchless min/max/abs network.** A live noisy source cleaned by a **9-element
    sorting network** built entirely from `min`/`max` compare-exchanges (branchless), median in the centre.
    *Stresses:* `G_SMIN`/`G_SMAX`/`G_UMIN`/`G_UMAX.lower()` (@272) and `G_ABS.custom()` (@281) as the **hot**
    op — select+icmp chains, a different lowering from #44's carry/V-flag saturation. *Shows:* snow/speckle
    noise wiped to a clean image, side-by-side before/after, sweeping.~~ ✓ [/snes/medfilt/](https://biohack.net/snes/medfilt/) — bit-exact `host==default==a16==xy16==0x87FE`; 19-comparator median-of-9 network, `(a<b)?a:b` → `G_UMIN/G_UMAX .lower()` (@272) → `cmp`+branch (no cmov on 65816), abs → `G_ABS`; zero mul/div libcalls; gate cross-checks the network median vs an insertion-sort median (0 mismatches / 200k tuples). Clean positive, no bug. ([plan](../plans/2026-06-30-57-snes-medfilt.md))

58. ~~**Complex domain-colouring with poles — NaN/unordered float compares.** Plot a rational complex function
    `f(z) = (z²−1)/(z²+c)` by domain colouring; near its **poles** the divide yields ∞/NaN and the code
    branches on `isnan`/`isinf` (`x != x`) to paint singularities distinctly. *Stresses:* `__unordsf2` /
    `__eqsf2` / `__nesf2` — equality + unordered/NaN tests, never used (only the ordered `<`). *Differential:*
    fold the **colour index**, not raw NaN bits (see gotcha). *Shows:* a smooth phase-coloured field with
    glowing pole singularities as `c` animates.~~ ✓ [/snes/domcol/](https://biohack.net/snes/domcol/) — bit-exact `host==default==a16==xy16==0xF3FD`; `isnan(x)=(x!=x)` → `__unordsf2` (the corner), one-reciprocal complex divide (`1/0=Inf`, `0*Inf=NaN`), folds the COLOUR INDEX not NaN bits; a guaranteed pole per gate iter. Soft-float is slow → 8×8 live "developing" render + palette shimmer, `GATE_N=4`. Clean positive, no bug. ([plan](../plans/2026-06-30-58-snes-domcol.md))

59. ~~**Powers-of-ten log ruler — 64-bit⇄float conversion.** A continuous logarithmic zoom from Planck length
    to the cosmos: a **`uint64` scale counter converted to `double`** each frame (`__floatdidf`) for
    log-scale positioning, tick labels back via `__fixdfdi`. *Stresses:* `__floatdidf` / `__fixdfdi` /
    `__floatdisf` / `__fixsfdi` — 64-bit-integer↔float conversion, never done (correctly-rounded → bit-exact).
    *Shows:* a smoothly gliding powers-of-ten ruler / scale-of-the-universe zoom.~~ ✓ [/snes/cosmzoom/](https://biohack.net/snes/cosmzoom/) — bit-exact `host==default==a16==xy16==0x502F`; uint64 scale → float (`__floatundisf`) for log positioning + round-trip back (`__fixunssfdi`) + signed `__floatdisf`/`__fixsfdi`. Used **float not double** (ROM/speed); `scale<10^18` so `(float)v→(uint64)` can't overflow-UB. Clean positive, no bug. ([plan](../plans/2026-06-30-59-snes-cosmzoom.md))

60. ~~**Multi-base chronometer — `div()`/`ldiv()` `div_t` struct-return.** One instant shown simultaneously in
    decimal, dozenal, hex and sexagesimal, each digit split with the libc **`div()`/`ldiv()` returning
    `div_t` by value** (quotient+remainder in one call). *Stresses:* the aggregate-return ABI **and** the
    custom `G_SDIVREM` stack-temp legalizer (@229) together — distinct from #39/#43's bare `/`,`%`. *Shows:*
    four rolling odometers ticking the same time in four bases.~~ ✓ [/snes/multibase/](https://biohack.net/snes/multibase/) — bit-exact `host==default==a16==xy16==0x371A`; real `div`/`lldiv` calls (aggregate-return ABI, confirmed via relocations) + `G_SDIVREM`; `div()` kept <32768 (16-bit int) + `lldiv()` 64-bit-safe (`ldiv` unused — width mismatch). Clean positive, no bug. ([plan](../plans/2026-06-30-60-snes-multibase.md))

61. ~~**Diffie–Hellman colour-mixer — 64-bit modular exponentiation.** Two "parties" exchange colours by
    **`gᵃ mod p` square-and-multiply** on 64-bit values, converging on a shared secret hue; also a
    modexp-driven pseudo-random Lissajous. *Stresses:* `__umoddi3` (64-bit `%`) as the **hot** op inside a
    square-and-multiply loop — neither #22's 64-bit hash (mul/shift/xor) nor #27's 16/32-bit `%`. *Shows:*
    two paint-swatches mixing to an identical secret colour, keys scrolling.~~ ✓ [/snes/dhmix/](https://biohack.net/snes/dhmix/) **🐞 CAUGHT + FIXED A REAL BACKEND BUG** — the 64-bit modexp crashed the `+mos-a16`/`+mos-xy16` legalizer (`unable to legalize G_UNMERGE_VALUES (s64)` / `G_ANYEXT (s24)`; default-8-bit OK). Fixed with the s64↔s16 (un)merge glue + odd-width anyext routing (patch `0017`, queued upstream). Post-fix bit-exact `host==default==a16==xy16==0x69AA`; corpus 62/62 green, no regression. ([plan](../plans/2026-06-30-61-snes-dhmix.md) · [investigation](2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md))

### Data structures & algorithms the battery never ran

62. ~~**Percolation / Kruskal maze — union-find path compression.** Randomly union neighbouring cells, watching
    clusters merge and a spanning path ignite the instant top connects to bottom (the percolation phase
    transition). *Stresses:* **disjoint-set with path compression** — the `find` that chases parent pointers
    *and rewrites them flat* in place; #18 (heap) / #31 (tree) never did this idiom. *Shows:* a grid of
    cells fusing into ever-larger coloured regions until one percolates and lights the whole path.~~ ✓ [/snes/percol/](https://biohack.net/snes/percol/) — bit-exact `host==default==a16==xy16==0x025B`; disjoint-set `find` with full path compression (walk to root, then re-point the whole path); wet region grows from the top until a white spanning cluster percolates to the bottom. Clean positive, no bug. ([plan](../plans/2026-06-30-62-snes-percol.md))

63. ~~**Dynamic range-sum bars — Fenwick / binary-indexed tree.** A live signal whose windowed sums drive an
    equaliser, maintained by a **Fenwick tree** (`i += i & -i` to update, `i -= i & -i` to query).
    *Stresses:* the `i & -i` **low-bit-isolation** two's-complement trick in a prefix-sum loop — a codegen
    shape nothing else emits. *Shows:* bars whose heights are O(log n) range sums, responding as points are
    added/removed.~~ ✓ [/snes/fenwick/](https://biohack.net/snes/fenwick/) — bit-exact `host==default==a16==xy16==0x3454`; BIT `update`/`query` walk via `i & -i` (width-safe `(uint16_t)(i & (uint16_t)(0u-i))`); a moving signal + its running integral (prefix sum) staircase; gate cross-checks BIT prefix vs a linear reference. Clean positive, no bug. ([plan](../plans/2026-06-30-63-snes-fenwick.md))

64. ~~**Radix-sort bars — non-comparison sort.** Animate a **counting/radix sort** of a bar array: histogram →
    prefix-sum → scatter, one digit pass at a time, **zero comparisons**. *Stresses:* the compare-free
    scatter-sort loop nest (histogram + prefix scan + stable scatter) — every #17 sort was comparison-based.
    *Shows:* bars re-bucketing pass by pass, stable within each digit, converging to sorted.~~ ✓ [/snes/radix/](https://biohack.net/snes/radix/) — bit-exact `host==default==a16==xy16==0x123E`; LSD radix base-16 (histogram + prefix-sum + stable scatter, zero data compares, 0 mul/div libcalls); bars sort into an ascending value-band gradient; gate cross-checks sorted (no inversions) + permutation (xor/sum). Clean positive, no bug. ([plan](../plans/2026-06-30-64-snes-radix.md))

65. ~~**Convex-hull rubber band — orientation cross-products.** Scattered moving points with their **convex
    hull** snapping taut around them (gift-wrap / Graham scan). *Stresses:* signed 2-D **cross-product
    orientation tests** (`(b−a)×(c−a)` sign) driving the branch decisions, plus an angular sort — never
    exercised. *Shows:* a drifting point cloud wrapped by a live rubber-band hull.~~ ✓ [/snes/hull/](https://biohack.net/snes/hull/) — bit-exact `host==default==a16==xy16==0x84E3`; gift-wrap (Jarvis) picks vertices from the sign of the **int32** cross product (cast to avoid 16-bit overflow), `__mulsi3`+`cmp`; amber rubber-band hull around a drifting cyan point cloud; gate cross-checks the hull is valid (all points left of every edge). Clean positive, no bug. ([plan](../plans/2026-06-30-65-snes-hull.md))

66. ~~**Edit-distance / knapsack DP — 2-D table + backtrack.** Fill a **dynamic-programming table** (Levenshtein
    or 0/1-knapsack) cell by cell, then trace the optimal path back through it. *Stresses:* a doubly-indexed
    memoised recurrence with data-dependent `min`/`max` reductions (also `G_SMIN`/`G_SMAX`) + a backtrack
    pointer walk — a new loop/GEP shape. *Shows:* the DP grid filling with a heat gradient, then the optimal
    alignment / packing path lighting up through it.~~ ✓ [/snes/editdist/](https://biohack.net/snes/editdist/) — bit-exact `host==default==a16==xy16==0xFB59`; Levenshtein `D[i][j]=min(sub,del,ins)` 2-D table + backtrack (min-of-3 `cmp`, doubly-indexed `D[i][j]`); cost heat-map with the traced alignment path, cycling word pairs; gate cross-checks symmetry `edit(A,B)==edit(B,A)`. Clean positive, no bug. ([plan](../plans/2026-06-30-66-snes-editdist.md))

67. ~~**Huffman decode reveal — bit-stream tree walk.** A compressed image decoded by a **bit-granular reader**
    (MSB-first) descending a **pointer-linked Huffman tree**, one bit per edge, emitting a symbol at each
    leaf. *Stresses:* the bit-reader (`code = (code<<1)|nextbit`) + tree-descent — distinct from #49's
    *byte*-oriented LZ back-refs. *Shows:* the classic progressive "image decoding in" reveal, bit by bit.~~ ✓ [/snes/huffman/](https://biohack.net/snes/huffman/) — bit-exact `host==default==a16==xy16==0xE8E4`; MSB-first bit reader + pointer-linked tree descent (`HF_KID0`/`HF_KID1`/`HF_SYM`), a 16×16 image decodes in bit by bit (concentric diamonds); gate cross-checks decode==original. Distinct from #49's byte LZ. Clean positive, no bug. ([plan](../plans/2026-06-30-67-snes-huffman.md))

### Rendering & geometry techniques with distinct codegen

68. ~~**Gradient-noise flow field — Perlin.** A flowing field where **Perlin gradient noise** (permutation
    table + Hermite **fade polynomial** `6t⁵−15t⁴+10t³` + gradient dot products + lerp) advects particles or
    warps a texture. *Stresses:* the perm-index + fade-polynomial + dot-of-gradients + interpolation pipeline
    — value-noise/plasma/CA never did gradient noise. *Shows:* organic drifting smoke / marble / flow-field
    streamlines.~~ ✓ [/snes/perlin/](https://biohack.net/snes/perlin/) — bit-exact `host==default==a16==xy16==0xA72D`; permutation table (seeded Fisher-Yates) + inline Hermite fade `6t⁵−15t⁴+10t³` (Q0.8, `__mulsi3`-heavy) + 4-way gradient dot + lerp; banded recompute of a drifting smoke/marble field. Clean positive, no bug. ([plan](../plans/2026-06-30-68-snes-perlin.md))

69. ~~**Gouraud triangle tumbler — barycentric edge functions.** A spinning solid whose faces are **filled and
    colour-interpolated** via edge-function rasterisation (three cross-product edge fns; inside = all signs
    agree; barycentric weights shade each pixel). *Stresses:* the edge-function sign tests + per-pixel
    barycentric interpolation inner loop — #16 drew wireframe **lines** only. *Shows:* a smoothly Gouraud-
    shaded rotating icosahedron / gem.~~ ✓ [/snes/gouraud/](https://biohack.net/snes/gouraud/) — bit-exact `host==default==a16==xy16==0xC5E9` on bsnes-jg; 3 int32 cross-product edge functions (`__mulsi3`) + per-pixel barycentric divide (`__divsi3`); a tumbling gold→orange→crimson Gouraud triangle. Correctness bar green; the `-verify` crash is the documented `a16-rc-undef-ra-pure-virtual` XFAIL (code bit-exact correct). A demo-only inverted-stepper-sign bug (invisible to the gate) was caught by host cross-check + fixed. ([plan](../plans/2026-06-30-69-snes-gouraud.md))

70. ~~**Error-diffusion camera — Floyd–Steinberg dither.** Reduce a smooth animated gradient scene to few
    colours by **Floyd–Steinberg error diffusion**, spreading the signed quantisation residual to
    down-right neighbours (7/16, 3/16, 5/16, 1/16) with saturation. *Stresses:* forward-carried **signed**
    error propagation + clamp across a scanline sweep — #7's fire was decay+PRNG, not error diffusion.
    *Shows:* a smooth scene resolving into shimmering ordered dither, the error visibly flowing.~~ ✓ [/snes/dither/](https://biohack.net/snes/dither/) — bit-exact `host==default==a16==xy16==0x80C4`, `-verify` clean ×2; two-row signed error buffer, residual split `(e*k)>>4` (arithmetic shift, no division), quantiser = 3 compares + 4-level LUT. A drifting gradient resolves into the 4-grey FS dither. Clean positive, no bug (incidental scene/index multiplies noted, cf #39). ([plan](../plans/2026-06-30-70-snes-dither.md))

71. ~~**Marching-squares contours — 16-case edge LUT.** Extract and animate the **iso-contours** of a scalar
    field (drifting metaball sum) via **marching squares**: a 16-entry case table selects which cell edges
    the contour crosses, then linear interpolation places the crossing. *Stresses:* the 16-case edge **LUT
    dispatch** + edge-crossing lerp — #45 rendered the metaball *field*; the contour is a separate case-table
    + interpolation. *Shows:* glowing iso-lines snaking around merging/splitting blobs.~~ ✓ [/snes/msquares/](https://biohack.net/snes/msquares/) — correctness green `host==default==a16==xy16==0x86A7` on bsnes-jg; 4-bit corner-sign case → 16-entry `MS_SEG` edge LUT + edge-crossing interpolation divide (`__divsi3`); yellow iso-outline around dim-filled merging blobs. The `-verify` crash is the documented `a16-rc-undef-ra-pure-virtual` XFAIL (divide-heavy, code bit-exact correct). Demo field made multiply-free via incremental second-difference stepping, host-cross-checked vs `ms_field`. ([plan](../plans/2026-06-30-71-snes-msquares.md))

72. ~~**3-D cellular automaton cube — multi-dimensional indexing.** A rotating **voxel cube** running a 3-D
    life-like automaton in a true `uint8 grid[Z][Y][X]` array with non-power-of-2 dimensions. *Stresses:*
    **compiler-generated N-D array address arithmetic** (`z*Y*X + y*X + x` GEP multiplies) — every prior grid
    was 1-D or hand-indexed. *Shows:* a slowly tumbling cube of cells being born and dying in 3-D.~~ ✓ [/snes/grid3d/](https://biohack.net/snes/grid3d/) — bit-exact `host==default==a16==xy16==0xFCDE`, `-verify` clean ×2; true `uint8 grid[6][6][6]` accessed `grid[z][y][x]` (compiler emits `z*36+y*6+x`; 26 Moore reads/cell) running a survive-4..7/born-5..6 3-D CA, tumbling as a depth-shaded voxel cube. Clean positive, no bug (caught+fixed a demo-only `CANVAS_FLUSH_TILES` display bug, ruled out a miscompile via default==a16). ([plan](../plans/2026-06-30-72-snes-grid3d.md))

## Round 4 first picks

Sharpest at opening a code path the first 52 never run:

- ~~**#53 bit-census (`popcount`/`clz`/`ctz`)** — the entire **bit-population intrinsic family**, never emitted
  once in 52 demos, plus the inline `G_CTPOP`/`G_CTLZ`/`G_CTTZ` shift-tree lowering. Largest brand-new
  surface, and an integer-exact differential.~~ ✓ [/snes/bitcensus/](https://biohack.net/snes/bitcensus/) — clean positive, no bug; the `ll` builtins inline-lower (SWAR), the `__*di2` helpers are never called.
- ~~**#56 rotozoom (`G_UMULH`)** — the **multiply-high** recognition the fixed-point demos never triggered
  (they forced full `__mulsi3`), wrapped in the most eye-catching visual of the set.~~ ✓ [/snes/rotozoom/](https://biohack.net/snes/rotozoom/) — clean positive; measured: the `G_SMULH.lower()` widens through `__muldi3`/`__mulsi3` (no narrower mul-high on a soft-multiply target).
- ~~**#57 median network (`G_SMIN`/`G_SMAX`/`G_ABS`)** — branchless min/max/abs as the hot op, a different
  lowering from #44's carry/V-flag saturation.~~ ✓ [/snes/medfilt/](https://biohack.net/snes/medfilt/) — clean positive; min/max `.lower()` → `cmp`+branch (no cmov), zero libcalls.
- ~~**#60 `div()`/`div_t`** — the libc struct-return-by-value *over* the custom `G_SDIVREM` stack-temp
  legalizer, two ABI paths braided together that #39/#43's bare `/`,`%` never touched.~~ ✓ [/snes/multibase/](https://biohack.net/snes/multibase/) — clean positive; real `div`/`lldiv` calls returning `div_t`/`lldiv_t` by value.
- ~~**#62 union-find percolation** — path-compression pointer-chase-and-flatten, a data structure neither
  #18's heap nor #31's tree exercised, with a gorgeous phase-transition visual.~~ ✓ [/snes/percol/](https://biohack.net/snes/percol/) — clean positive; the wet region percolates into a white spanning cluster.

Each would be built on `snesgfx` the same way as the first 52: a shared host+target logic header, a
`dev/run.sh <name>` differential gate, and a two-emulator screenshot — the picture *is* the proof.
