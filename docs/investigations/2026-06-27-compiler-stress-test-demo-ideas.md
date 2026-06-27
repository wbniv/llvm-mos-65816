# SNES 65816 compiler stress-test demos — 20 ideas (algorithm + visual)

A backlog of candidate demo programs whose job is to **stress the llvm-mos 65816 codegen** — each leans
on a different corner of the compiler (32-bit/fixed-point multiply, division, recursion + the soft stack,
multi-precision carry chains, bit manipulation, shift-add, far/high-WRAM pointers under `+mos-a16`, function
pointers) **and renders the computation itself** on screen, so the visual *is* the proof, not a side channel.

These complement the demos already built: the fixed-point **Mandelbrot** (Mode 7, far stores —
[`examples/snes/mandel-display.c`](../../examples/snes/mandel-display.c)), the **Blossom** Hopalong attractor,
and **Space Invaders** on the `snesgfx` OOP library
([plan](../plans/2026-06-26-space-invaders-on-the-snesgfx-oop-library.md)). None of the 20 below duplicate those.

## The bar each demo should meet (so it's a real test, not a toy)

Mirror the established pattern (see `mandel.h` / `invaders_logic.h`):

1. **Shared host+target logic header** — the math/algorithm in pure `<stdint.h>` C (explicit `int16_t`/`int32_t`
   widths; `int` is 16-bit on target, 32-bit on host), compiled both on the SNES and by a host oracle.
2. **Differential CRC** — fold the result/state into a CRC; assert **host == default@MAME == +mos-a16@MAME ==
   +mos-xy16@MAME == default/+mos-a16@bsnes-jg**, `-verify-machineinstrs` clean, bsnes 3× byte-identical.
3. **On-screen render via `snesgfx`** — sprites or a Mode 7 / BG buffer that visualises the computation;
   two-emulator screenshot.

Builds default-8-bit unless it needs a far/high-WRAM framebuffer (then `+mos-a16`, like Mandelbrot).

---

## Fractals & complex iteration — fixed-point mul/div, tight per-pixel loops

1. **Julia set explorer** — `z²+c` with `c` animated along a path. *Stresses:* Q-format complex multiply,
   far high-WRAM framebuffer (a16). *Shows:* morphing Julia fractal.
2. **Newton's-method fractal** — `z − p(z)/p′(z)` for `z³−1`, colour by which root it converges to.
   *Stresses:* complex **division** (the hard one) + convergence branching. *Shows:* basins of attraction.
3. **Burning Ship / Multibrot** — `|Re|,|Im|` folding, or `zᵈ`. *Stresses:* extra multiplies, abs, `pow`
   loops. *Shows:* the ship / d-fold bulb.
4. **Buddhabrot** — accumulate *escaping* orbit visits into a density buffer. *Stresses:* scatter writes to a
   far buffer + PRNG sampling. *Shows:* the ghostly orbit-density image.

## Cellular automata & grids — bit-twiddling, array indexing, double-buffer

5. **Conway's Game of Life** — bit-packed neighbour sums, ping-pong buffers. *Stresses:* bitops, array index,
   two-buffer swap. *Shows:* gliders/guns evolving.
6. ~~**Rule 90/110 (1-D CA)** — each row from the previous via 8-bit logic. *Stresses:* shifts/boolean logic.
   *Shows:* Sierpinski (90) / chaos (110) scrolling down — the display *is* the computation.~~ ✓ [/snes/1d-ca/](https://biohack.net/snes/1d-ca/)
7. **Doom-fire / heat field** — per-cell decay + PRNG, palette ramp. *Stresses:* array sweep + rng + CGRAM.
   *Shows:* animated fire from the heat array.
8. **Reaction–diffusion (Gray–Scott)** — two-chemical PDE, Laplacian, mul-add per cell. *Stresses:* heavy
   fixed-point **mul-add** loops. *Shows:* Turing spots/stripes self-organising.

## Trig / parametric — sin-cos LUTs, fixed-point accumulation

9. **Lissajous / harmonograph** — damped `sin(at), sin(bt+φ)` plotting. *Stresses:* sin LUT + fixed-point mul
   + accumulation. *Shows:* the decaying traced curve.
10. **Fourier epicycles** — sum of rotating vectors traces a shape. *Stresses:* many sin/cos + complex add.
    *Shows:* nested circles drawing an outline.
11. ~~**Spirograph (hypotrochoid)** — `(R, r, d)` parametric. *Stresses:* sin/cos + mul. *Shows:* the rose pattern.~~ ✓ [/snes/spirograph/](https://biohack.net/snes/spirograph/)
12. **CORDIC clock/rotator** — sin/cos/atan via **shift-add only** (no multiply). *Stresses:* shift-add
    convergence loops — a different ALU profile from everything else. *Shows:* a rotating hand with its angle.

## Physics & numerical integration — fixed-point, division, sqrt

13. ~~**N-body orbits** — Newtonian gravity, Verlet, `1/r²`. *Stresses:* fixed-point mul + **division** +
    integration. *Shows:* planets orbiting with fading trails.~~ ✓ [/snes/n-body/](https://biohack.net/snes/n-body/)
14. ~~**Double pendulum (chaos)** — Euler/RK integration with sin. *Stresses:* sin + sensitive fixed-point
    integration. *Shows:* the chaotic swing + path trace.~~ ✓ [/snes/double-pendulum/](https://biohack.net/snes/double-pendulum/)
15. **Raycaster maze** — DDA grid cast, wall height = `1/dist` per column. *Stresses:* fixed-point +
    **per-column division**. *Shows:* first-person 3-D corridors.
16. ~~**Wireframe 3-D solid** — rotation matrix (sin/cos LUT), perspective projection (divide), Bresenham lines.
    *Stresses:* 3×3 matrix mul + projection divide + line raster. *Shows:* a spinning cube/icosahedron.~~ ✓ [/snes/3d-wireframe/](https://biohack.net/snes/3d-wireframe/)

## Discrete algorithms, data structures & big-integers — recursion, heaps, carry chains

17. **Sorting race** — animate quicksort vs heapsort vs mergesort of a bar array. *Stresses:* recursion (soft
    stack / frame ABI), compares, in-place swaps. *Shows:* bars sorting in real time.
18. **Maze generate + solve** — DFS carve (recursion) then A*/BFS (priority-queue frontier). *Stresses:*
    recursion + a heap/queue data structure + array. *Shows:* maze built, then the shortest path lit.
19. ~~**π — spigot digits + Monte-Carlo** — unbounded spigot (big-int mul/div/mod) alongside a Buffon/dart
    estimate. *Stresses:* multi-precision **carry chains** + div/mod + rng. *Shows:* digits ticking out beside
    a dart scatter with the running estimate.~~ ✓ [/snes/spigot/](https://biohack.net/snes/spigot/)
20. **Bignum factorial / Fibonacci** — `1000!` or `Fib(5000)` in a digit array, schoolbook carry mul/add.
    *Stresses:* multi-precision **carry propagation** across arrays. *Shows:* the giant number filling the
    screen + its digit count.

---

## Coverage map (why this is a good battery, not 20 of the same test)

| Codegen aspect | Demos |
|---|---|
| complex / 32-bit fixed-point **multiply** | 1–4, 8, 9–11, 13, 16 |
| **division** / reciprocal / sqrt | 2, 13, 15, 16, 19 |
| **recursion** & the soft stack / frame ABI | 17, 18 |
| **heaps / queues / structs** (data structures) | 18 |
| **bit manipulation** (pack/shift/boolean) | 5, 6 |
| multi-precision **carry-chain** codegen | 19, 20 |
| **shift-add**, multiply-free | 12 |
| **far / high-WRAM** buffers (a16-only) | 1, 4, 8, 13 |
| **PRNG + scatter** writes | 4, 7, 19 |
| **sin/cos LUT** indexing | 9–11, 14, 16 |

## Recommended first picks

Sharpest compiler stress for the effort, each hitting a corner the existing demos don't:

- **#2 Newton's-method fractal** — complex **division** per pixel (Mandelbrot is multiply-only).
- ~~**#16 wireframe 3-D solid** — matrix multiply + perspective **divide** + line rasterisation.~~ ✓
- **#19 / #20 big-integer** — multi-precision **carry-chain** codegen, untouched by every other demo. (#19 ✓)
- **#12 CORDIC** — a **multiply-free** shift-add inner loop (and the repo already has CORDIC tables).

Each would be built on `snesgfx` the same way as Space Invaders: a shared host+target logic header, a
`dev/run.sh <name>` differential gate, and a two-emulator screenshot.
