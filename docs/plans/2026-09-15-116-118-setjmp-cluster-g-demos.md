# Round 6 Cluster G (#116–#118) — hardening the 65816-native `setjmp.S` fix

> **STATUS 2026‑09‑15: #116 and #117 COMPLETE and gated; #118 STOPPED on a second, unrelated
> defect it found.** The cluster has now caught two real bugs.
>
> 1. **#116 `backtrack`** surfaced a high-severity runtime defect on its very first run:
>    `longjmp`'s page‑1 hard-stack reconstruction never executed, because the assembler sizes a
>    plain immediate by its value, not by the `rep #$20` mode it follows — so `and #$00ff` encoded
>    as an 8-bit operand while the CPU, already in 16-bit mode, read 2 bytes for it at runtime,
>    consuming the next instruction's opcode. **FIXED** in `platforms/snes/setjmp.S` (one line, the
>    existing `mos16()` immediate-width modifier):
>    [investigation](../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md#resolution-2026-09-15).
>    #116 is now fully shipped — `expected.tsv` row, `dev/backtrack.sh` driver, visual ROM with a
>    title card, `Taskfile.yml` + `dev/run.sh` wiring. Gate `0x7336`.
> 2. **#117 `csrjmp`** is fully shipped the same way. Gate `0xADD8`. The CSR restore is correct:
>    all 14 coefficients survive, all three modes, both emulators.
> 3. **#118 `retryjmp`** found a **second, still-OPEN defect — a real `+mos-xy16` MISCOMPILE**
>    (not a verifier-only complaint): the frame-index address materialization for a spill slot
>    takes the live `Imag16` pair holding the value about to be stored, so a 16-bit indexed store
>    writes the index expression instead of the value. Default and `+mos-a16` are correct; `xy16`
>    gives `0x82D4` against the host's `0x3388`. Root cause, assembly, reduction and the reason
>    the existing `KNOWN_ISSUES` text-match would wrongly classify it as the benign
>    `a16-rc-undef-ra-pure-virtual` XFAIL:
>    [investigation](../investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md).
>    **#118 is committed UN-GATED** — logic header + host oracle + corpus slice only, no
>    `expected.tsv` row, no `dev/retryjmp.sh`, no visual ROM. **ESCALATED**: the fix is a backend
>    register-scavenger / frame-index-elimination change plus a full toolchain rebuild and
>    regression sweep.
>
> Per the battery's own rule — *demos exist to find compiler bugs* — neither demo was ever
> weakened to ship around the defect it found.


Three SNES stress-test demos that escalate past `corpus/setjmp_sim.c` (one frame, one jump, no
live callee-saved registers) into the three corners where a page‑1‑S‑reconstruct /
CSR‑restore‑offset / re‑entry defect would hide.

- Bug under guard: **#35** — the SDK's common `mos-platform/common/c/setjmp.S` is 6502-only;
  `longjmp`'s `tax; txs` restore drops the native 16‑bit `S` into page 0, so `longjmp` `rts`-es to
  garbage. Fixed 2026‑07‑02 by a shadowing `platforms/snes/setjmp.S` that reconstructs the page‑1
  16‑bit `S` (`ora #$0100; tcs`) and reads/writes the return address stack-relative.
- Records: [investigation](../investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md) ·
  [fix plan](2026-07-02-35-setjmp-longjmp-65816-fix.md) ·
  [cluster spec](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md) (lines ~1361‑1445).

**Mockups:** none. The visible surface of each demo is a real SNES frame, and the gate itself
produces it — `build/<demo>-{mame,jg}.png` are emulator screenshots, which is stronger evidence
than a hand-drawn mockup. This matches every other demo plan in `docs/plans/2026-07-02-*`.

## The bar

Each demo carries the project differential plus the cluster's own multi-mode requirement:

| Leg | Where it runs |
|---|---|
| host oracle | `tools/<demo>-sim.c` built with the host `cc` |
| default‑8‑bit @ MAME | `dev/run.sh corpus` (manifest row) |
| default‑8‑bit == `+mos-a16` == `+mos-xy16` @ MAME, `+mos-a16` @ bsnes‑jg | `dev/run.sh corpus-a16` (the differential engine, `tools/a16_fuzz.py check`) |
| `+mos-a16` @ MAME **and** @ bsnes‑jg, with a screenshot | `dev/run.sh <demo>` |
| `-verify-machineinstrs` clean under `+mos-a16` and `+mos-xy16` | inside the `corpus-a16` engine |

Reconciling the spec's "5‑way bar (`setjmp`/`longjmp` must be correct in default **and**
`+mos-a16` **and** `+mos-xy16`)" with what the harness actually enforces: the five agreeing
legs are **host == default@MAME == `+mos-a16`@MAME == `+mos-xy16`@MAME == `+mos-a16`@bsnes‑jg**,
which is precisely what a `corpus/` manifest row buys (the same structure `corpus/setjmp_sim.c`
= `0x2007` already uses). The per-demo `dev/<demo>.sh` adds the rendered `+mos-a16` ROM asserted
on both emulators plus a disasm/structure gate. So every demo ships a `corpus/<demo>_sim.c`
slice **and** a `dev/<demo>.sh` driver — the corpus slice is what makes the bar five-way.

## #116 `backtrack` — the flagship guard

8‑queens, six independent searches (column order rotated per run so each search takes a
different path).

- `bt_descend(row)` is `noinline` and recursive: it `setjmp`s its own choice point
  `bt_cp[row]`, places the first safe column, and recurses. It **never returns** — every exit is
  a `longjmp`.
- On a dead end at depth `d`, `bt_backjump(d)` walks to the **deepest ancestor `k` that still has
  a safe, untried column** and `longjmp`s straight to `bt_cp[k]`, unwinding `d − k` `jsr` frames
  in one jump. Skipping ancestors whose remaining columns are all unsafe is sound (they would be
  exhausted immediately), so the search stays a complete, deterministic backtracking search while
  the unwind depth varies from 1 frame to many.
- A full board `longjmp`s to `bt_root` — `BT_N + 1` frames at once.
- All state that changes between `setjmp` and `longjmp` is file-scope, never a clobbered local.
- Gate CRC folds the six solution grids, the `solved` flags, `visits`, `backs`, the **summed
  unwind depth** `bt_frames`, the total event count, and the recorded event trace. A botched
  unwind corrupts the counters *and* the board.
- Visual: the recorded trace is replayed on a 8×8 board (2×2 tiles per cell) — the board fills,
  then snaps back on each backtrack, with the abandoned rows flashing.

## #117 `csrjmp` — the CSR-restore-offset guard

A `setjmp` brackets a parametric-curve (harmonograph) evaluation with 14 simultaneously-live
coefficient bytes — the width of the `__rc18..__rc31` callee-saved block the fix renumbers.

- The coefficients are loaded, the `setjmp` is taken, a `noinline` worker scribbles over every
  callee-saved slot and `longjmp`s back, and the coefficients are then used to render.
- An off-by-one in the restore offsets corrupts exactly one coefficient → one axis of the curve
  warps visibly and the CRC diverges.
- Gate CRC folds the post-`longjmp` coefficient vector **and** the rendered curve samples.

## #118 `retryjmp` — the re-entry guard

One `setjmp` site re-entered many times.

- A `noinline` recursive `rj_work(depth, …)` carries many locals (deep soft stack) and `longjmp`s
  back to the single `setjmp` on a simulated fault, from a depth that varies per attempt.
- The `setjmp` site must stay re-enterable: soft-SP restore × page‑1 `S` reconstruct × return
  address rewrite all interact on every retry.
- Gate CRC folds the retry-outcome sequence (attempt index, fault code, depth, work result).
- Visual: a progress bar advancing per successful attempt plus a depth gauge.

## Files

Per demo `<d>` ∈ {`backtrack`, `csrjmp`, `retryjmp`}:

- `examples/65816/<d>.h` — shared host+target logic (the gate)
- `examples/65816/sjcompat.h` — shared `setjmp`/`longjmp` declarations (new, used by all three)
- `examples/snes/<d>.c` — demo ROM
- `examples/snes/corpus/<d>_sim.c` + a row in `examples/snes/corpus/expected.tsv`
- `tools/<d>-sim.c` — host oracle
- `dev/<d>.sh` + `dev/<d>.lua` — driver + MAME assert
- `dev/run.sh` — usage line + target description
- `Taskfile.yml` — `task <d>` / `task <d>-play`

`#118 retryjmp` ships only the first, third (as the repro, not a ROM) and fifth of those — the
`expected.tsv` row, the driver, the `dev/run.sh`/`Taskfile.yml` wiring and the visual ROM are all
withheld while the `+mos-xy16` miscompile it found is open.

## Verification

1. `dev/run.sh backtrack`
2. `dev/run.sh csrjmp`
3. `dev/run.sh retryjmp`
4. `dev/run.sh corpus`
5. `dev/run.sh corpus-a16`
6. `dev/run.sh build` (full example battery)
7. `dev/title-charset.sh`

### Fix verification (2026‑09‑15, after the investigation's Resolution)

`platforms/snes/setjmp.S` fixed (`and #$00ff` → `and #mos16($00ff)`), SDK rebuilt
(`dev/run.sh build`, `EXIT=0`, `256 built / 3 excluded by contract / 0 failed`).

`sjreturn_min.c`, rebuilt and re-gated:
```
SMOKE: PASS off=0x20 len=2 got=0xF00D (ran 300 frames, bsnes-jg)
```

`corpus/setjmp_sim.c`'s existing 5-way guard — unaffected by the fix, still PASS at `0x2007`
(carried by the `corpus`/`corpus-a16` re-run below).

`#116 backtrack`'s corpus slice, rebuilt and re-gated, all three modes, bsnes-jg, 300 frames,
matching the host oracle's `gate_crc = 0x7336` above exactly:
```
default corpus_result@0x200 -> SMOKE: PASS off=0x200 len=2 got=0x7336
a16     corpus_result@0x200 -> SMOKE: PASS off=0x200 len=2 got=0x7336
xy16    corpus_result@0x200 -> SMOKE: PASS off=0x200 len=2 got=0x7336
```

`dev/run.sh corpus` re-run on the fixed toolchain: `63/63 passed` (unchanged).

`dev/run.sh corpus-a16` re-run on the fixed toolchain (`build/fuzz-work` wiped first — see the
gotcha below): `62/62 passed, 0 xfail`, `setjmp_sim` unchanged at `0x2007`:

```
==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg; settle=1000)
  arith      PASS   corpus_result=0xA9E9  8/16/32-bit integer ALU
  control    PASS   corpus_result=0x1DFB  loops / if / switch
  arrays     PASS   corpus_result=0x03E1  arrays + .rodata lookup table
  structs    PASS   corpus_result=0x0340  struct layout + pointer deref
  funcs      PASS   corpus_result=0x011E  calls + recursion (soft stack)
  globals    PASS   corpus_result=0xAB55  crt0 .data copy + .bss clear
  invaders_sim PASS   corpus_result=0x9D57  Space Invaders deterministic attract sim, 600 frames (shared invaders_logic.h)
  spiro_sim  PASS   corpus_result=0x32D4  spirograph (R,r,d) hypo/epi/rose/lissajous curve-point hash, 32 pts x 4 modes (shared spiro.h)
  spiro_ctrl_sim PASS   corpus_result=0x6A26  spirograph interactive controller + HUD-format math over a scripted pad sequence (shared spirograph.h)
  pi_sim     PASS   corpus_result=0x7711  π spigot (PI_GATE_DIGITS=1, PI_ELEMS=676, a[0]=0) + MC (PI_GATE_THROWS=256) gate CRC (shared pi_spigot.h)
  ca1d_sim   PASS   corpus_result=0xAB2C  1-D CA: 32 Rule-90 + 32 Rule-110 gens from single-cell seed; CRC-16 of all output rows (shared ca1d.h)
  rdiff_sim  PASS   corpus_result=0x5555  Gray-Scott cumulative gate_crc (16-bit fixed-point, scale 4096; GS_GATE_W=8, GS_GATE_H=8, GS_GATE_STEPS=8; DU=655/DV=328/F=150/K=254)
  nbody_sim  PASS   corpus_result=0xCC65  N-body (N=3, GRAV_K=64, GRAV_SOFT=16, DT_SHIFT=4) Symplectic Euler, 32 steps, rotate-XOR CRC
  factorial_sim PASS   corpus_result=0x772F  Bignum factorial 50! in base-10000 uint16 array; carry-mul + __mulsi3 + __udivmodsi4 (shared factorial.h)
  newton_sim PASS   corpus_result=0x4D8B  Newton's-method fractal z³−1, 8×8 grid in [−1.2,1.2]², 20-iter cap; complex division + multiply (shared newton.h)
  cordic_sim PASS   corpus_result=0x4D41  CORDIC rotator full-circle sweep (GATE_N=96): rotation cordic16_sincos + vectoring cordic16_atan2, shift-add only → zero mul/div libcalls (shared cordic.h)
  maze_sim   PASS   corpus_result=0x0749  Maze recursive-division generate + A* indexed-heap solve (16x15) gate CRC: walls + path + heap counters (shared maze.h)
  doom-fire_sim PASS   corpus_result=0x3C59  Doom-fire heat field: 16x16 grid, 30 steps; per-cell xorshift16 PRNG + flat-index array sweep (multiply-free), rotate-XOR CRC of full grid each step (shared doom-fire.h)
  life_sim   PASS   corpus_result=0xDDF1  Conway's Game of Life B3/S23: Gosper gun on 64x48 bitpacked grid, 32 gens; SWAR bit-parallel neighbour sums (and/eor/ora + asl/lsr, multiply-free), CRC-16 of all output rows (shared life.h)
  epicycles_sim PASS   corpus_result=0x4F6C  Fourier epicycles: sum of 8 rotating vectors (DFT of a star) traces the outline; 4 __mulsi3/harmonic + 32-bit accumulate, no divide (shared epicycles.h)
  julia_sim  PASS   corpus_result=0x3490  Julia set z^2+c escape-time: 4 keyframe c's (0.7885*e^itheta orbit, 90 deg steps) over a 6x6 grid, maxiter 8; 3 __mulsi3/iter Q5.10 complex multiply (shared julia.h)
  harmonograph_sim PASS   corpus_result=0x0EBB  Lissajous/harmonograph: 4 damped pendulums (2/axis, detuned), 256 samples preset 0; 8 __mulsi3/sample (sin·env amplitude + env·decay envelope), sin LUT, rotate-XOR hash, no divide (shared harmonograph.h)
  raycaster_sim PASS   corpus_result=0xB200  Raycaster maze DDA grid-cast: 64-column fan from a fixed camera, 16x16 map; 3 __udivsi3/column (deltaDist reciprocals + screen_h/dist), Q8.8 fixed-point + sin LUT (shared raycaster.h)
  burning-ship_sim PASS   corpus_result=0x6F2D  Burning Ship fractal (|Re|,|Im| fold): 16x16 window over the ship, maxiter 24; 3 __mulsi3/iter (zx2,zy2,|zx*zy|) Q12 + 2 abs folds, escape-time hash, no divide (shared burning_ship.h)
  mandel-float_sim PASS   corpus_result=0x4169  Soft-float Mandelbrot escape-time (IEEE-754 single precision): 2 zoom windows on a 6x6 grid (maxiter 12) + 24-step bit-exact orbit witness; every op is a soft-float libcall (__mulsf3/__addsf3/__subsf3/__divsf3/__gtsf2/__floatsisf), bit-for-bit host==target (shared mandel-float.h)
  avalanche_sim PASS   corpus_result=0x27EA  64-bit Avalanche: 256 chained splitmix64 (2 __muldi3 + shifts incl. >>32 + variable 1ULL<<i) folded with 64-bit xor/add and a runtime __udivdi3 into a CRC16; exercises the 64-bit integer libcall family bit-exact host==target (shared avalanche.h)
  boids_sim  PASS   corpus_result=0xA8AB  Boids struct-by-value steering: 8-bird flock, 12 steps; vec2 take/return-by-value kernel (v2_add/v2_sub/v2_scale + separation/alignment/cohesion, noinline) exercises the aggregate-return ABI; __mulsi3 + __divsi3 fixed-point, far-pointer-free, rotate-XOR CRC of pos/vel (shared boids.h)
  turtle-vm_sim PASS   corpus_result=0x4007  Bytecode-VM turtle dispatch: stack-machine interpreter (dense switch -> JMP (abs,X) jump table + function-pointer ALU opcode table via __call_indir) runs a 180-step turtle program, rotate-XOR CRC of the path; near fnptrs + bank-0 data, far-pointer-free; exercises indirect/computed control flow bit-exact host==target (shared turtle_vm.h)
  lsystem_sim PASS   corpus_result=0x8073  L-system string rewriting: axiom rewritten 6 generations IN PLACE in a grown char buffer (memmove tail-shift + memcpy production + strlen), then a turtle interprets it with a [ ]/ bracket push-pop stack into a fractal plant, rotate-XOR CRC of the path; bank-0 buffers, far-pointer-free; exercises string libcalls + save/restore stack bit-exact host==target (shared lsystem.h)
  truchet_sim PASS   corpus_result=0xB3E6  Truchet packed-bitfield maze: 16x14 grid of uint16 bitfield cells (orient/style/hue/phase/mark/energy), 24 wave steps, folds EXTRACTED field values; exercises bitfield insert/extract codegen (and/ora/shift, no libcalls), bit-exact host==target (shared truchet.h)
  wire3d_sim PASS   corpus_result=0xE737  3-D wireframe projected-vertex gate: 3x3 rotation matrix (Q8.8, __mulsi3) + per-vertex perspective divide (__divsi3) of each of 30 verts (tetra/cube/octa/icosa) projected once across 4 fixed non-trivial orientations; rotate-XOR hash of (sx,sy); near, far-pointer-free; sized for the 60-frame corpus settle window; matrix-mul + divide hot path bit-exact host==target (shared wire3d.h)
  wire3d_ctrl_sim PASS   corpus_result=0xE3CD  3-D wireframe interactive controller + HUD-format math over a scripted pad sequence: solid/palette/trail edge controls + spin-rate/dolly level controls + auto-spin angle wrap + decimal HUD format; CRC16-CCITT; bit-exact host==target (shared wireframe.h)
  fn_plot_sim PASS   corpus_result=0x2EBE  fn-plot recursive-descent parser + soft-float evaluator: 64 x-samples of x*x-0.5 in [-2,2), CRC of IEEE float bit-patterns; exercises fn_eval_expr→fn_eval_term→fn_eval_factor recursion + __mulsf3/__subsf3/__addsf3/__divsf3/__fixsfsi; bit-exact host==target (shared fn_plot.h)
  cardioid_sim PASS   corpus_result=0x523B  Cardioid times-table modulo gate: k*(i+65536) % N for k=2..8 x i=0..199, rotate-XOR CRC of j; exercises __mulsi3 (genuinely 32-bit product via +65536 offset) + __umodsi3, bit-exact host==target (shared cardioid.h)
  tea_sim    PASS   corpus_result=0xDF0E  TEA cipher gate: 8 plaintexts x 32 rounds with fixed 128-bit key; fold v[0]^v[1] via rotate-XOR; exercises 32-bit <<4/>>5 constant shifts + 32-bit add/XOR chains, multiply-free; rep/sep=22 under +mos-a16; inline ASL+ROL expansion (no __ashlsi3 at -Os); bit-exact host==target (shared tea.h)
  hilbert_sim PASS   corpus_result=0x5999  Hilbert order-4 d2xy+xy2d round-trip gate: all 256 points, fold rt+(rt<<2)+x+(y<<8); variable-count 32-bit shifts __ashlsi3(rx,k)+__lshrsi3(x,k) (k=0..3 loop var); rep/sep=23, __mulsi3=0; bit-exact host==target (shared hilbert.h)
  fft_sim    PASS   corpus_result=0x6D7A  32-point DIT FFT gate: sawtooth signal, 5 stages × 16 butterflies × 4× __mulsi3 (butterfly twiddle complex multiply); bit-reversal permutation; rep/sep=63; bit-exact host==target (shared fft.h)
  vaprintf_sim PASS   corpus_result=0xE1F3  Variadic va_arg gate: 4× mini_sprintf calls, 9× va_arg(unsigned int/int); formats '123+456', '-7/3', 'beef cafe', '999 -1 abcd'; folds output chars; bit-exact host==target (shared vaprintf.h)
  bhut_sim   PASS   corpus_result=0xEF0B  Barnes-Hut quadtree N-body gate: 8 particles, 6 steps; recursive bh_insert/bh_force walk pooled-node tree via runtime child[] indices (pointer-chasing) + gravity kernel __mulsi3(5)/__divsi3(4); rep/sep=160, bh_force self-recursion; bit-exact host==target (shared bhut.h)
  mandel-double_sim PASS   corpus_result=0x0EDF  Double-precision soft-float Mandelbrot: a 5x5 double escape buffer + a 5x5 float twin (whole-set window, maxiter 6) + a 12-step bit-exact double orbit witness (raw 64-bit |z|^2 bits) + a double<->float conversion witness; exercises the 64-bit soft-float library (__muldf3/__adddf3/__subdf3/__gtdf2/__floatsidf) plus __truncdfsf2/__extendsfdf2, bit-exact host==target (shared mandel-double.h)
  bitcensus_sim PASS   corpus_result=0x9516  Bit-population intrinsic family gate: popcount/clz/ctz/parity of coords; the ll builtins inline-lower to SWAR (G_CTPOP/CTLZ/CTTZ .lower @308), __*di2 helpers never called; bit-exact host==target (shared bitcensus.h)
  bitshuffle_sim PASS   corpus_result=0x2A4A  bswap/bit-reverse intrinsic gate: __builtin_bswap32 + __builtin_bitreverse (G_BITREVERSE .lower @186), bit-reversal permutation (an involution); both inline-lower; bit-exact host==target (shared bitshuffle.h)
  gf256_sim  PASS   corpus_result=0xC028  GF(2^8) carryless-multiply gate: log/antilog tables + XOR (gf_mul), no adc carry chain, 0 mul/div libcalls; cross-checked vs a slow bit-by-bit carryless multiply; bit-exact host==target (shared gf256.h)
  rotozoom_sim PASS   corpus_result=0x391B  widening multiply-high gate: (coord*scale)>>16 via G_SMULH .lower @300 degrading to __muldi3/__mulsi3 on the soft-multiply target; Q16.16 affine sampler; bit-exact host==target (shared rotozoom.h)
  medfilt_sim PASS   corpus_result=0x87FE  branchless min/max/abs network gate: 19-comparator median-of-9 via G_UMIN/UMAX .lower @272 + G_ABS @281; cross-checked vs insertion-sort median; bit-exact host==target (shared medfilt.h)
  domcol_sim PASS   corpus_result=0xF3FD  NaN/unordered float-compare gate: (z^2-1)/(z^2+c) domain colouring, isnan(x)=(x!=x)->__unordsf2, folds the COLOUR INDEX not NaN bits, a guaranteed pole per iter; one-op-per-statement soft-float; bit-exact host==target (shared domcol.h)
  cosmzoom_sim PASS   corpus_result=0x502F  64-bit int<->float conversion gate: uint64 scale -> float (__floatundisf) round-trip (__fixunssfdi) + signed __floatdisf/__fixsfdi; scale<10^18; correctly-rounded, bit-exact host==target (shared cosmzoom.h)
  multibase_sim PASS   corpus_result=0x371A  div_t/lldiv_t struct-return-by-value gate: div()/lldiv() aggregate-return ABI over the custom G_SDIVREM @229; DEC/DOZ/HEX/SEX split; bit-exact host==target (shared multibase.h)
  dhmix_sim  PASS   corpus_result=0x69AA  64-bit modular-exponentiation gate: __umoddi3 as the hot op in square-and-multiply (Diffie-Hellman); the slice that caught the s64 unmerge/anyext legalizer crash (fixed, patch 0017); bit-exact host==target (shared dhmix.h)
  percol_sim PASS   corpus_result=0x025B  union-find path-compression gate: disjoint-set find walks parent ptrs to root then re-points the whole path flat; bond percolation; bit-exact host==target (shared percol.h)
  fenwick_sim PASS   corpus_result=0x3454  Fenwick/BIT i&-i low-bit-isolation gate: update i+=i&-i, query i-=i&-i (width-safe (uint16)(i&(uint16)(0u-i))); prefix sums; bit-exact host==target (shared fenwick.h)
  radix_sim  PASS   corpus_result=0x123E  non-comparison sort gate: LSD radix base-16 histogram+prefix-sum+stable-scatter, zero data compares, 0 mul/div libcalls; cross-checks sorted+permutation; bit-exact host==target (shared radix.h)
  hull_sim   PASS   corpus_result=0x84E3  convex-hull orientation gate: gift-wrap picks vertices from the sign of the int32 cross product (cast int16 diffs -> __mulsi3); cross-checks hull validity; bit-exact host==target (shared hull.h)
  editdist_sim PASS   corpus_result=0xFB59  2-D DP table gate: Levenshtein D[i][j]=min(sub,del,ins) doubly-indexed table + backtrack (min-of-3 cmp); cross-checks symmetry edit(A,B)==edit(B,A); bit-exact host==target (shared editdist.h)
  huffman_sim PASS   corpus_result=0xE8E4  Huffman bit-stream decode gate: MSB-first bit reader + pointer-linked tree descent (HF_KID0/KID1/SYM); cross-checks decode==original; bit-exact host==target (shared huffman.h)
  perlin_sim PASS   corpus_result=0xA72D  Perlin gradient-noise gate: Fisher-Yates permutation + inline Hermite fade 6t^5-15t^4+10t^3 (Q0.8, __mulsi3-heavy) + 4-way gradient dot + lerp; bit-exact host==target (shared perlin.h)
  gouraud_sim PASS   corpus_result=0xC5E9  barycentric edge-function raster gate: 3 int32 cross-product edge fns (__mulsi3) + per-pixel barycentric divide (__divsi3); trips the a16/xy16 -verify rc-undef XFAIL (code bit-exact correct); host==target (shared gouraud.h)
  dither_sim PASS   corpus_result=0x80C4  Floyd-Steinberg signed error-diffusion gate: two-row error buffer, residual split (e*k)>>4 arithmetic shift, quantiser 3 compares + 4-level LUT, no division; bit-exact host==target (shared dither.h)
  msquares_sim PASS   corpus_result=0x86A7  marching-squares gate: 4-bit corner-sign case -> 16-entry MS_SEG edge LUT + edge-crossing interpolation divide (__divsi3); trips the a16/xy16 -verify rc-undef XFAIL (code correct); host==target (shared msquares.h)
  grid3d_sim PASS   corpus_result=0xFCDE  multi-dimensional array indexing gate: true uint8 grid[6][6][6] accessed grid[z][y][x] (compiler emits z*36+y*6+x), Moore-26 3-D life CA; bit-exact host==target (shared grid3d.h)
  setjmp_sim PASS   corpus_result=0x2007  setjmp/longjmp non-local return on the 65816 native 16-bit stack (regression guard for the 6502-only common setjmp.S; #35)
  nmitally_sim PASS   corpus_result=0xBCE6  #123 VBlank Interrupt Tally arithmetic gate (ORACLE form, no interrupts): 240 fenced ticks of xorshift16 + 16-bit multiply-add + 16x16->32 __mulsi3 accumulate, folded 4 rotations/tick; the interrupt-CC half is asserted separately by dev/nmitally.sh
==> corpus-a16: 62/62 passed, 0 xfail
```

### Gotcha found along the way: `tools/a16_fuzz.py`'s shared scratch files

While chasing this re-run, `dev/run.sh corpus-a16` was accidentally run twice concurrently earlier
(this run and a leftover background verification another agent had left running). Every failure
that produced showed the same fingerprint: one demo's reported `+mos-xy16@MAME` or `+mos-a16@bsnes`
hash was some OTHER demo's *correct expected* hash — e.g. `life_sim`'s wrong value was exactly
`perlin_sim`'s `0xA72D`. Cause: `tools/a16_fuzz.py`'s `evaluate()` compiles every single demo to the
same fixed filenames — `build/fuzz-work/chk_default.sfc` / `chk_a16.sfc` / `chk_xy16.sfc` — not one
per demo name, and `build/` is host-mounted into every `dev/run.sh` container (`-v "$ROOT":/work`
in `dev/run.sh`), so two concurrent `corpus-a16` runs (even in separate containers) race on the same
physical files on the host. Worse: the corruption **persisted across later, non-concurrent re-runs**
until `build/fuzz-work` was deleted — a stale or partially-written `.sfc`/`.map` pair from the race
survived on disk and kept getting read. See the "Concurrent `dev/run.sh` invocations" note added to
`docs/agent-handoff.md`.

### Results (2026‑09‑15, second pass) — #116 and #117 GREEN, #118 STOPPED on a new defect

Steps are the seven numbered above, in order, with raw output.

**1. `dev/run.sh backtrack`**

```
==> host oracle: backtrack gate hash = 0x7336
==> built build/backtrack.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (setjmp + longjmp calls present, bt_descend is a real jsr frame)
    PASS  setjmp=2  longjmp=3  bt_descend refs=72  (choice points + backjumps present)
==> bsnes-jg: render + assert (build/backtrack-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0x7336 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/backtrack-mame.png)
    SHOT: PASS corpus=0x7336 (snapshot at frame 600)

RESULT: PASS — Backtracking Solver on SNES; MAME + bsnes-jg + corpus hash 0x7336 host == +mos-a16
```

**PASS.** MAME really ran — the SPC700 IPL is present on this host, so neither emulator leg SKIPped.

**2. `dev/run.sh csrjmp`**

```
==> host oracle: csrjmp gate hash = 0xADD8
==> built build/csrjmp.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (setjmp + longjmp present, __rc2x callee-saved block occupied, __mulsi3)
    PASS  setjmp=1  longjmp=1  __rc20..31 refs=315  __mulsi3=6
==> bsnes-jg: render + assert (build/csrjmp-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0xADD8 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/csrjmp-mame.png)
    SHOT: PASS corpus=0xADD8 (snapshot at frame 600)

RESULT: PASS — Callee-Saved Restore Curve on SNES; MAME + bsnes-jg + corpus hash 0xADD8 host == +mos-a16
```

**PASS.** The MIR confirms the shape under test: 12 of the 14 coefficients are held in
`__rc20..__rc31` across the `setjmp`, the other two on the soft stack, and `cj_worker` rewrites all
of them before jumping. Every one comes back intact.

**3. `dev/run.sh retryjmp`: NOT RUN — the demo is STOPPED.** There is no `dev/retryjmp.sh`, by
design: the slice found a real `+mos-xy16` miscompile and the gate must not be weakened to ship
around it. The evidence, produced directly.

Host oracle (`tools/retryjmp-sim.c`, `cc -O2 -Wall -Wextra`):

```
retryjmp attempts=24 wins=8 calls=117
  attempt  0 code=  2 deepest=1 result=0x46B9
  attempt  1 code=  4 deepest=3 result=0x4A64
  attempt  2 code=  0 deepest=4 result=0x1298
  ...
  attempt 23 code=  0 deepest=9 result=0x8E8F
retryjmp gate_crc = 0x3388
```

`-verify-machineinstrs`:

```
default  exit=0
a16      exit=0
xy16     exit=1   *** Bad machine code: Using an undefined physical register *** (2 errors)
```

Target, bsnes-jg, `corpus/retryjmp_sim.c` linked with `--config mos-snes.cfg`:

```
default  SMOKE: PASS off=0x20 len=2 got=0x3388 (ran 600 frames, bsnes-jg)
a16      SMOKE: PASS off=0x20 len=2 got=0x3388 (ran 600 frames, bsnes-jg)
xy16     SMOKE: FAIL off=0x20 len=2 got=0x82D4 want=0x3388
```

Stable at 400/1200/2400 frames. Root cause, the wrong assembly, the reduction and the ruling-out
of `setjmp.S`: [the investigation](../investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md).
**ESCALATED** — a backend fix, out of scope here.

**4. `dev/run.sh corpus`**

```
  backtrack_sim PASS  corpus_result=0x7336  #116 setjmp/longjmp multi-frame unwind gate …
  csrjmp_sim PASS  corpus_result=0xADD8  #117 setjmp/longjmp callee-saved-restore gate …
  setjmp_sim PASS  corpus_result=0x2007  setjmp/longjmp non-local return on the 65816 native 16-bit stack …
==> corpus: 65/65 passed
```

**PASS.** 63 → 65 (the two new rows). `setjmp_sim` unchanged at `0x2007`.

**5. `dev/run.sh corpus-a16`** (`build/fuzz-work` + `build/fuzz-triage` wiped first; run strictly
serially — no second `corpus`/`corpus-a16` invocation anywhere on the box)

```
  setjmp_sim PASS   corpus_result=0x2007  setjmp/longjmp non-local return on the 65816 native 16-bit stack …
  backtrack_sim PASS   corpus_result=0x7336  #116 setjmp/longjmp multi-frame unwind gate …
  csrjmp_sim PASS   corpus_result=0xADD8  #117 setjmp/longjmp callee-saved-restore gate …
==> corpus-a16: 64/64 passed, 0 xfail
```

**PASS.** 62 → 64 (the two new rows), 0 xfail, `setjmp_sim` unchanged at `0x2007`. Every row is
`host == default == +mos-a16 == +mos-xy16` on MAME + bsnes-jg.

**6. `dev/run.sh build`** (full example battery)

```
==> built 260 program(s)
==> not programs, excluded by contract (3): snes-video-codec snes-video-dma snes-video-stream
```

**PASS.** 256 → 260: `examples/snes/backtrack.c`, `examples/snes/csrjmp.c`,
`examples/snes/corpus/csrjmp_sim.c`, `examples/snes/corpus/retryjmp_sim.c`. No errors, no failures.

**7. `dev/title-charset.sh`**

```
checked 127 title call sites across 140 demo sources
PASS  every title character has a glyph
```

**PASS** — covers the two new title cards (`8-QUEENS BACKJUMP` / `BACKTRACK` and
`CALLEE-SAVED RESTORE` / `CSRJMP`).

**Extra — `-verify-machineinstrs` on both new corpus slices, all three modes** (exit status, not
piped):

```
backtrack default exit=0     csrjmp default exit=0
backtrack a16     exit=0     csrjmp a16     exit=0
backtrack xy16    exit=0     csrjmp xy16    exit=0
```

#### First-pass record (2026‑09‑15, before the `setjmp.S` fix)

Kept because it is what found the `#35` defect. `dev/run.sh backtrack` did not exist yet; the
equivalent evidence, produced directly:

Host oracle (`tools/backtrack-sim.c`, `cc -O2 -Wall -Wextra`):

```
backtrack visits=265 backs=83 frames=201 events=348 traced=348
backtrack gate_crc = 0x7336
```

`-verify-machineinstrs`, all three modes, clean (exit 0 each):

```
--- flags: default
  exit=0
--- flags: -Xclang -target-feature -Xclang +mos-a16
  exit=0
--- flags: -Xclang -target-feature -Xclang +mos-xy16
  exit=0
```

Target, bsnes-jg, `corpus/backtrack_sim.c` linked with `--config mos-snes.cfg`, 1200 frames:

```
default corpus_result@0x200 -> SMOKE: FAIL off=0x200 len=2 got=0x0000 want=0x7336
a16     corpus_result@0x200 -> SMOKE: FAIL off=0x200 len=2 got=0x0000 want=0x7336
xy16    corpus_result@0x200 -> SMOKE: FAIL off=0x200 len=2 got=0x0000 want=0x7336
```

Bisected from there to a 12‑line repro that has nothing to do with N‑Queens
([`sjreturn_min.c`](../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes/sjreturn_min.c)) —
`longjmp` back into a non‑`main` function which then *returns*:

```
SMOKE: FAIL off=0x20 len=2 got=0x1111 want=0xF00D
```

and to the byte-level cause in `platforms/snes/setjmp.S:170‑173`. Full write-up:
[the investigation](../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md).

At that point `csrjmp` and `retryjmp` were not started — both are `setjmp`/`longjmp` demos and
would have failed identically, producing two more un-gateable ROMs and no new information.

## Deferred

- The `+mos-xy16` spill-address/live-`Imag16` miscompile `#118` found is OPEN and needs a backend
  fix (register scavenger / frame-index elimination) plus a full toolchain rebuild and regression
  sweep — out of the scope of the demo pass that found it.
  [investigation](../investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md)
- `#118 retryjmp`'s remaining half — the `expected.tsv` row (`0x3388`), `dev/retryjmp.{sh,lua}`,
  the visual ROM (progress bar + depth gauge), the `dev/run.sh` and `Taskfile.yml` wiring — is
  withheld until that fix lands, then wired exactly as `#116`/`#117` are.
- `tools/a16_fuzz.py`'s `KNOWN_ISSUES` classifies any log containing
  `"Using an undefined physical register"` as the benign, verifier-only
  `a16-rc-undef-ra-pure-virtual` XFAIL. The `#118` miscompile emits that exact string *and* a
  wrong answer, so the classifier needs a discriminator stronger than the message text.
- `corpus/setjmp_sim.c` is not a sufficient guard for the `#35` bug class on its own — it never
  *returns* from its `setjmp` frame. `#116 backtrack` now covers that; a dedicated minimal guard
  that only returns out of a `setjmp` frame would still be cheaper to run.
