# SNES 65816 compiler stress-test demos (algorithm + visual)

> **Status (2026-06-29).** **Round 1 (#1–#20) — all 20 shipped** ✓, published on
> [biohack.net/snes](https://biohack.net/snes/); the differential gate found a handful of pre-existing
> compiler bugs along the way. **Round 2 (#21+) — in progress** (#21 ✓ [soft-float](https://biohack.net/snes/mandel-float/),
> #22 ✓ [64-bit avalanche](https://biohack.net/snes/avalanche/) shipped 2026-06-29), below: each targets a
> **codegen corner the first 20 never execute** (soft-float,
> 64-bit integers, jump tables, by-value struct ABI, bitfields, variadics, variable-count shifts,
> pointer-chasing trees) — the untested libcall/ABI paths where the remaining bugs hide.

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
| **soft-float (IEEE-754)** — `__addsf3`/`__mulsf3`/`__divsf3`/`__ltsf2`/`__floatsisf`/`__fixsfsi` | no Round-1 demo uses `float` at all; single-precision is fully specified → bit-exact differential | ~~21~~, 24 |
| **64-bit integers** — `__muldi3`/`__udivdi3`/`__ashldi3`/`__lshrdi3`, 4-limb carry | every Round-1 demo tops out at 32-bit | ~~22~~ |
| **jump-table / computed branch** — switch-dispatch + indirect-call tables | never exercised | 24, 29a |
| **aggregate / by-value struct ABI** — sret vs register-pair return | structs exist (#18) but are never passed/returned **by value** | 26 |
| **bitfield insert/extract** — `unsigned x : n` fields | zero usage so far | 29b |
| **variable-count shifts** — `__ashlsi3`/`__lshrsi3` with a *data-dependent* count | all Round-1 shifts are compile-time constants | 28, 30 |
| **variadic `va_arg`** — the stack-walking calling convention | untouched | 32 |
| **string / char-array building** — `memcpy`/`memmove`/`strlen` over grown buffers | untouched | 23, 24 |
| **pointer-chasing dynamic trees** — recursive build/walk over pooled nodes | #18's heap is a flat array, not a linked structure | 31 |
| **modulo-heavy** inner loop — `__umodhi`/`__umodsi3` per iteration | div appears, but never `%` as the hot op | 27 |
| **bit-reversal / interleave permutation** | never exercised | 25, 28 |

## Highest bug-yield — brand-new libcall/ABI paths

21. ~~**Soft-float Mandelbrot / plasma (IEEE-754)** — render in `float` instead of fixed-point. *Stresses:* the
    **entire soft-float library**. The differential is razor-sharp — single precision is fully specified, so
    host `float` must equal target soft-float **bit-for-bit**; any rounding/conversion bug shows instantly.
    *Shows:* the fractal, with a fixed-point twin for the timing contrast. ← **sharpest first pick.**~~ ✓ [/snes/mandel-float/](https://biohack.net/snes/mandel-float/) *(bit-exact host==default==a16==xy16 `0x4169`; no compiler bug — soft-float codegen correct across all modes)*
22. ~~**64-bit hash plasma / xorshift64 field** — `__muldi3`, 64-bit shifts/xor, carry across 4 limbs.
    *Shows:* an avalanche field (flip one input bit → output bits cascade) or a hash-coloured plasma.
    *(Variant: Q16.48 **deep-zoom** Mandelbrot whose multiply needs a 64-bit intermediate.)*~~ ✓ [/snes/avalanche/](https://biohack.net/snes/avalanche/) *(splitmix64 matrix; bit-exact host==default==a16==xy16 `0x27EA`; disasm `__muldi3`+`__udivdi3`+64-bit shift; no bug)*
26. **Boids flocking (struct-by-value vectors)** — steering functions take/return `vec2` **by value**.
    *Stresses:* the **aggregate-return ABI** (sret vs register pair), invoked thousands of times/frame.
    *Shows:* a flock swirling — separation / alignment / cohesion.
29a. **Bytecode-VM turtle** — a stack machine interpreting a compiled program. *Stresses:* **jump-table
    dispatch** + a function-pointer opcode table. *Shows:* turtle graphics driven by bytecode.
32. **printf HUD (variadic)** — a tiny `vsnprintf` driving a readout; exercises **`va_arg`**. Best *folded
    into* another demo's HUD rather than built standalone.

## Strong stressors with great visuals

23. **L-system turtle** — string rewriting (char-array grow, `memmove`) + bracket **push/pop** of turtle
    state + sin/cos. *Shows:* Koch / dragon curve / algorithmic plant growing.
24. **Recursive-descent function plotter** — a real **recursive-descent parser** (deep recursion + string
    scan) feeding a switch-dispatch evaluator; pairs with soft-float (#21) for the eval. *Shows:* type-in
    `y=f(x)` plotted live.
25. **Radix-2 FFT spectrum analyser** — **bit-reversal permutation** + in-place butterfly loops + twiddle
    complex-multiply. *Shows:* animated frequency bars of a synthesised chord.
27. **Times-table cardioid** — `(k·i) mod N` per chord around a circle, animated `k`; **modulo-heavy** inner
    loop. *Shows:* the morphing cardioid / nephroid envelope.
28. **Hilbert / Gray-code curve** — bit-interleave + **variable-count** shifts/rotates + recursion.
    *Shows:* the space-filling curve at rising order.
29b. **Truchet tiles (packed bitfields)** — per-cell state as `unsigned : n` bitfields; stresses
    insert/extract. *Shows:* a curved-tile labyrinth.
30. **TEA / XTEA cipher avalanche** — tight 32-bit mix (data-dependent shifts + adds + xor + magic delta).
    *Shows:* encrypt the framebuffer; one bit flip → avalanche.
31. **Barnes-Hut quadtree galaxy** — recursive build/walk over a **pooled struct-node tree** (distinct from
    #13's flat-array N-body). *Shows:* a galaxy with the quadtree overlaid.

## Round 2 first picks

Sharpest at opening a code path the first 20 never run:

- ~~**#21 soft-float** — largest untested surface, and a bit-exact differential.~~ ✓ [/snes/mandel-float/](https://biohack.net/snes/mandel-float/)
- ~~**#22 64-bit integers** — `__muldi3` & friends, never touched.~~ ✓ [/snes/avalanche/](https://biohack.net/snes/avalanche/)
- **#26 struct-by-value ABI** — aggregate return on a hot path.
- **#29a jump-table VM** — indirect dispatch / function-pointer table.
