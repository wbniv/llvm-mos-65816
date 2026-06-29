// #1 SNES compiler stress-test — fixed-point Julia-set escape-time kernel.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/julia.c), the corpus
// slice (examples/snes/corpus/julia_sim.c), and the host oracle (tools/julia-sim.c). Because the
// host (int = 32-bit) and llvm-mos (int = 16-bit) both compile THIS code, the result is bit-
// identical on every platform ONLY because every narrowing is an explicit fixed-width cast and
// every product is forced through int32_t. Do not "simplify" a cast away — it is load-bearing for
// the differential gate.
//
// Math: signed Q5.10 fixed point (1.0 == 1024). z_{n+1} = z_n^2 + c, escape when |z|^2 > 4.
// THIS IS THE JULIA VARIANT of mandel.h: z_0 = the PIXEL coordinate and c is a single complex
// CONSTANT for the whole frame (animated along a path), whereas Mandelbrot has c per-pixel and
// z_0 = 0. The escape-time inner loop is otherwise identical — three 16x16->32 fixed-point
// multiplies per iteration (zr^2, zi^2, zr*zi), zr/zi held live across the loop: exactly the
// >1-live-16-bit-value pressure +mos-a16 targets.
#ifndef JULIA_H
#define JULIA_H

#include <stdint.h>

#define JULIA_Q       10               /* fractional bits: 1.0 == 1<<10 == 1024 */
#define JULIA_ONE     (1 << JULIA_Q)
#define JULIA_RE0     (-1638)          /* -1.6 * 1024  (z0 real, left edge)  */
#define JULIA_IM0     (-1638)          /* -1.6 * 1024  (z0 imag, top edge)   */
#define JULIA_REW     3276             /*  3.2 * 1024  (window width,  real) */
#define JULIA_IMW     3276             /*  3.2 * 1024  (window height, imag) */
#define JULIA_ESCAPE  (4 << JULIA_Q)   /* |z|^2 > 4.0 in Q5.10               */

// c-path: 16 keyframes around the circle of radius 0.7885 (Q5.10 == round(0.7885*1024) == 807) —
// the classic Julia-morph orbit. As theta sweeps the set morphs between connected blobs and
// disconnected Fatou dust. A baked const table is trivially host==target identical.
//   python3 -c 'import math;R=807;N=16;print([(round(R*math.cos(2*math.pi*p/N)),round(R*math.sin(2*math.pi*p/N))) for p in range(N)])'
#define JULIA_NPHASE  16
static const int16_t JULIA_CPATH[JULIA_NPHASE][2] = {
  {  807,    0}, {  746,  309}, {  571,  571}, {  309,  746},
  {    0,  807}, { -309,  746}, { -571,  571}, { -746,  309},
  { -807,    0}, { -746, -309}, { -571, -571}, { -309, -746},
  {    0, -807}, {  309, -746}, {  571, -571}, {  746, -309},
};

// Escape count for one pixel: z0 = (zr,zi), constant c = (cr,ci), all Q5.10. The hot path: three
// 16x16->32 fixed-point multiplies per iteration, holding zr/zi live across the loop.
//
// noinline (the mandel_cell pattern): the 16-bit accumulator state crosses the call boundary every
// pixel, so +mos-a16 drops to 8-bit at the call and re-enters 16-bit inside — a realistic exercise.
// It is ALSO load-bearing: inlining the cell into the fill into main piles every loop's 16-bit live
// ranges together and overflows the imaginary-register file (a -verify-machineinstrs failure under
// the neutral --target=mos path; same family as the known a16regpress issue). Keep noinline.
__attribute__((noinline)) static uint8_t julia_cell(int16_t zr, int16_t zi,
                                                    int16_t cr, int16_t ci, uint8_t maxiter) {
  uint8_t n;
  for (n = 0; n < maxiter; n++) {
    // Products are int32; >> JULIA_Q brings Q10.20 back to Q5.10. The (int32_t) cast on one operand
    // forces a 32-bit multiply on both host and target.
    int32_t zr2 = ((int32_t)zr * zr) >> JULIA_Q;
    int32_t zi2 = ((int32_t)zi * zi) >> JULIA_Q;
    if (zr2 + zi2 > JULIA_ESCAPE) break;             /* escaped */
    // Held in int32 until the explicit (int16_t) narrowing wraps identically on both platforms.
    // While NOT escaped, |zr|,|zi| <= 2048, so these fit int16 exactly (no actual wrap).
    int16_t tmp = (int16_t)(zr2 - zi2 + cr);
    zi = (int16_t)(2 * (((int32_t)zr * zi) >> JULIA_Q) + ci);
    zr = tmp;
  }
  return n;
}

// Fill a w*h row-major buffer (1 byte/pixel = escape count) for Julia constant c = (cr,ci). Window
// steps are DERIVED (dre = REW/w, dim = IMW/h) so host == target by construction at any grid size.
static inline void julia_fill(uint8_t *fb, uint8_t w, uint8_t h,
                              int16_t cr, int16_t ci, uint8_t maxiter) {
  int16_t dre = (int16_t)(JULIA_REW / w);
  int16_t dim = (int16_t)(JULIA_IMW / h);
  for (uint8_t j = 0; j < h; j++) {
    int16_t zi0 = (int16_t)(JULIA_IM0 + (int16_t)j * dim);
    for (uint8_t i = 0; i < w; i++) {
      int16_t zr0 = (int16_t)(JULIA_RE0 + (int16_t)i * dre);
      uint16_t idx = (uint16_t)((uint16_t)j * w + i);
      fb[idx] = julia_cell(zr0, zi0, cr, ci, maxiter);
    }
  }
}

// 5-bit-per-channel palette (BGR555-ready) for escape count n; interior (n>=maxiter) is black.
// Shared so the on-console CGRAM (SNES_RGB(r,g,b)) renders the bands consistently. Same shape as
// mandel.h's mandel_palette — a fiery low-to-high ramp.
static inline void julia_palette(uint8_t n, uint8_t maxiter, uint8_t *r5, uint8_t *g5, uint8_t *b5) {
  if (n >= maxiter) { *r5 = 0; *g5 = 0; *b5 = 0; return; }
  uint8_t t = (uint8_t)((unsigned)n * 31u / (maxiter ? maxiter : 1));   // 0..31
  *r5 = t;
  *g5 = (uint8_t)((t < 16) ? (t * 2) : 31);
  *b5 = (uint8_t)(31 - t);
}

// CRC16-CCITT (XModem: poly 0x1021, init 0xFFFF, MSB-first, no reflection) over the whole buffer.
// The (uint16_t)x << 8 casts force unsigned-int promotion on the 16-bit-int target (avoiding
// signed-overflow UB) and re-truncate so host and target agree bit-for-bit. A CRC match proves the
// ENTIRE buffer is identical; a codegen bug corrupts many pixels, so a false pass is impossible.
static inline uint16_t julia_crc(const uint8_t *fb, uint16_t len) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < len; k++) {
    crc ^= (uint16_t)((uint16_t)fb[k] << 8);
    for (uint8_t b = 0; b < 8; b++) {
      if (crc & 0x8000)
        crc = (uint16_t)((uint16_t)(crc << 1) ^ 0x1021);
      else
        crc = (uint16_t)(crc << 1);
    }
  }
  return crc;
}

#define JULIA_GATE_W     6u            /* gate grid width  */
#define JULIA_GATE_H     6u            /* gate grid height */
#define JULIA_GATE_N     8u            /* maxiter for the gate (escape 0..8)   */
#define JULIA_GATE_STEP  4u            /* fold every 4th keyframe (4 of 16, full circle at 90 deg) */

// Differential anchor: fold 4 keyframe escape buffers (6x6 grid each, stepping the orbit by 90 deg)
// into a 16-bit rotate-xor of their CRC16s. Sized so the boot-time compute finishes comfortably
// within the corpus harness's 180-frame / 3-second budget (tools/a16_fuzz.py gives each slice 180
// bsnes-jg frames) while still issuing well over a thousand Q5.10 __mulsi3 products. Deterministic,
// far-pointer-free (36-byte low-WRAM static buffer), so the corpus slice runs the FULL 5-way
// differential. A `static` buffer (not a local) keeps the soft-stack frame tiny.
static inline uint16_t julia_gate_crc(void) {
  static uint8_t buf[JULIA_GATE_W * JULIA_GATE_H];
  uint16_t h = 0;
  for (uint8_t p = 0; p < JULIA_NPHASE; p += JULIA_GATE_STEP) {
    julia_fill(buf, (uint8_t)JULIA_GATE_W, (uint8_t)JULIA_GATE_H,
               JULIA_CPATH[p][0], JULIA_CPATH[p][1], (uint8_t)JULIA_GATE_N);
    uint16_t c = julia_crc(buf, (uint16_t)(JULIA_GATE_W * JULIA_GATE_H));
    h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ c);
  }
  return h;
}

#endif /* JULIA_H */
