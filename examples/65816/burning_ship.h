/* burning_ship.h — shared, PURE Burning Ship fractal: the single source of truth for the host oracle
 * (tools/burning-ship-sim.c), the corpus differential slice (examples/snes/corpus/burning-ship_sim.c),
 * and the on-screen renderer (examples/snes/burning-ship.c). Same body on host (int = 32) and the 65816
 * target (int = 16), so host == target bit-for-bit by construction — every width cast is load-bearing.
 *
 * The Burning Ship is the Mandelbrot's folded cousin:  z_{n+1} = (|Re z_n| + i|Im z_n|)² + c.  Taking
 * the absolute value of each component before squaring breaks the symmetry and renders the famous
 * "ship" silhouette. Per iteration: three Q12 fixed-point multiplies (zx², zy², |zx·zy|) — the same
 * count as Mandelbrot — PLUS the two abs folds that ARE the algorithm. Escape-time bands colour it.
 *
 * Codegen under test: `__mulsi3` (3×/iteration) + the abs branch/negate + the escape compare, all in
 * Q12 fixed point. All integer ⇒ host == target; the escape grid lives in bank-0 WRAM (no far
 * pointers) ⇒ the full 5-way bar. See docs/plans/2026-06-28-3-snes-burning-ship.md. */
#ifndef BURNING_SHIP_H
#define BURNING_SHIP_H

#include <stdint.h>

#ifndef BS_FN
#define BS_FN __attribute__((noinline)) static
#endif

#define BS_FX     12          /* Q12 fixed point: range ±8 (zx,zy ≤ 2 before escape), precision 1/4096 */
#define BS_ESCAPE (4 << BS_FX) /* |z|² > 4 ⇒ escaped */

/* Escape-time for c = (cx,cy) (Q12): iterate z₀=0 under the Burning Ship map, return the iteration
 * count at which |z|² first exceeds 4, or maxiter if it never escapes. The three Q12 multiplies +
 * two abs folds per step are the declared stress. */
BS_FN uint8_t bs_iter(int16_t cx, int16_t cy, uint8_t maxiter) {
  int16_t zx = 0, zy = 0;
  uint8_t n;
  for (n = 0; n < maxiter; n++) {
    int16_t ax = (int16_t)(zx < 0 ? -zx : zx);          /* |Re z| — the fold */
    int16_t ay = (int16_t)(zy < 0 ? -zy : zy);          /* |Im z| — the fold */
    int32_t zx2 = ((int32_t)ax * ax) >> BS_FX;          /* Q12 — __mulsi3 */
    int32_t zy2 = ((int32_t)ay * ay) >> BS_FX;          /* Q12 — __mulsi3 */
    if (zx2 + zy2 > BS_ESCAPE) break;                   /* |z|² > 4 */
    int32_t zxy = ((int32_t)ax * ay) >> BS_FX;          /* Q12 |zx·zy| — __mulsi3 */
    zx = (int16_t)(zx2 - zy2 + cx);                     /* Re: zx² − zy² + cx */
    zy = (int16_t)(2 * zxy + cy);                       /* Im: 2|zx·zy| + cy  */
  }
  return n;
}

/* Cheap 16-bit rotate-left-xor rolling hash (the spiro.h idiom). */
static inline uint16_t bs_fold(uint16_t h, uint16_t v) {
  uint16_t hi = (uint16_t)((h >> 15) & 1u);
  return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ v);
}

/* Gate grid: a fixed window over the ship, escape counts folded into a rolling hash. */
#define BS_GATE_W     16u
#define BS_GATE_H     16u
#define BS_GATE_MAXI  24u
#define BS_GATE_X0   ((int16_t)-7373)   /* -1.80 in Q12 */
#define BS_GATE_Y0   ((int16_t)-7373)   /* -1.80 in Q12 */
#define BS_GATE_DX    ((int16_t)205)    /*  0.050 in Q12 per cell → window ~0.8 wide */
#define BS_GATE_DY    ((int16_t)205)

/* The differential gate: sweep a 16×16 window over the ship, fold each cell's escape count — a codegen
 * defect in any multiply / abs / compare perturbs the hash on the first wrong cell. */
BS_FN uint16_t bs_gate_crc(void) {
  uint16_t h = 0;
  for (uint8_t r = 0; r < BS_GATE_H; r++) {
    int16_t cy = (int16_t)(BS_GATE_Y0 + (int16_t)((int16_t)r * BS_GATE_DY));
    for (uint8_t col = 0; col < BS_GATE_W; col++) {
      int16_t cx = (int16_t)(BS_GATE_X0 + (int16_t)((int16_t)col * BS_GATE_DX));
      h = bs_fold(h, (uint16_t)bs_iter(cx, cy, (uint8_t)BS_GATE_MAXI));
    }
  }
  return h;
}

#endif /* BURNING_SHIP_H */
