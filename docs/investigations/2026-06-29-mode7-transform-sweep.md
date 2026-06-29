# Mode-7 transform / "screen goes black" sweep — all 4 hand-built Mode-7 demos

**Date:** 2026-06-29. **Trigger:** while building #22 (64-Bit Avalanche) a reviewer noticed the demo
periodically collapsed to black. The cause was a **malformed Mode-7 matrix**, a class of bug that a code
read can miss — so we swept *every* hand-rolled Mode-7 demo for the same failure mode.

## The two failure modes

1. **Degenerate affine matrix.** A Mode-7 matrix `[[A,B],[C,D]]` maps screen→texture. If its determinant
   `A·D − B·C` reaches **0**, the transform is singular and the whole image collapses to a point/line →
   black. The trap: writing a *rotation* with **mismatched scales** on the four terms. A correct rotation
   is `A=D=cos·z, B=−sin·z, C=sin·z` (one shared scale `z`), giving `det = cos²z² + sin²z² = z²` — never
   zero as long as `z≠0`. Avalanche used `A=D=cos·0x40` but `B=C=sin·0x10` (two different scales), so
   `det = cos²·0x40² + sin²·0x10²` → at `cos=0` it dropped to `sin²·0x10²` and the off-diagonal-only matrix
   collapsed the image. **Every quarter turn it went black.**
2. **Content goes black.** The transform is fine but the *thing being displayed* is mostly the dark set
   interior — e.g. a Mandelbrot deep-zoom whose thin escape filaments alias to black on a coarse grid.

## Method (the load-bearing part)

A **code read is not enough** — mandel-float's transform was provably correct yet the demo still went
black (failure mode 2). The reliable check is **empirical**: render real bsnes-jg frames across the whole
animation cycle and measure **per-frame mean luma + non-black %**. A near-zero luma frame is a red flag;
then *view* it to classify (degenerate smear vs legitimate-dark content). `jgxcheck <rom> <db> <off> 2
<crc> <frame> <out.png>` renders a single frame; a Python/PIL one-liner reduces each to `(luma, non-black%)`.

## Findings

| Demo | Transform | Empirical visual | Verdict |
|---|---|---|---|
| **#22 avalanche** | ✗ degenerate (`A=D=cos·0x40`, `B=C=sin·0x10` → singular at `cos=0`) | black every ¼ turn (frames 255/285/360 luma 0) | **BUG → fixed** |
| **#21 mandel-float** | ✓ proper rotation (`det=z²`, `z∈[0x20,0x40]`) | deep-zoom windows W2–W5 near-black + torn wipes (frames 2400–2760 luma 7–10, 3–5% non-black) | **BUG (content) → fixed** |
| **#1 julia** | ✓ proper rotation (`det=z²`) | bright across the entire `c`-morph orbit incl. the sparse "Fatou dust" keyframes (frames 800–4500 luma 60–190, 72–96% non-black) | **clean** |
| **#4 buddhabrot** | ✓ single **fixed** axis-aligned `m7_set_matrix(MAG,0,0,MAG)` — structurally immune | faint-by-design ghost; luma climbs 0→6→11 as orbits accumulate (the intended progressive bloom, recognizable buddha by ~frame 5000) | **clean** |

The 15 `Display`-pipeline demos (Bresenham / `BitmapCanvas` / sprite based) don't program raw Mode-7
affine matrices, so they are not exposed to failure mode 1.

## Fixes (both shipped + redeployed)

- **#22 avalanche** — `drift_frame` rewritten to an **axis-aligned zoom-breathe** (`A=D` near `0x40`,
  never near 0; keeps the rainbow bands horizontal, which are semantic). Also: the boot was a ~7 s black
  screen because the gate (256 × 64-bit `__udivdi3`) ran before display — now **chunked** across frames
  (a replica of `h64_gate_crc`, byte-identical → `0x27EA`); and `compute_col` bit-extraction switched
  from 56 variable 64-bit shifts/column to four 16-bit-word splits. Commit `8c3373a`; live biohack
  `v1.0.127` (selfcheck offset corrected `0x200`→`0x20` — the gate-state vars shifted WRAM).
- **#21 mandel-float** — display capped to **W0 only** (`DISP_NWIN=1`), the iconic whole set, with the
  Mode-7 spin + zoom-breathe + palette cycle as the motion (W0 re-ground each pass so the soft-float keeps
  running); `DN` 8→12 for richer bands. Gate unchanged `0x4169`. Commit `c911efd`; live biohack `v1.0.129`.

## Lesson

The "best visual" verdict for a Mode-7 demo can only be reached by **rendering and measuring**, not
reading the matrix math. Two of four hand-built demos had defects (one transform, one content); both were
invisible to inspection and obvious to a luma sweep. Keep `m7_set_matrix` rotations to the
single-shared-scale form, and luma-sweep any new Mode-7 demo before publishing. See also the parallel
[V-blank / flicker sweep](../plans/2026-06-29-snes-vblank-flicker-sweep.md) (the "writes only in V-blank" axis).
