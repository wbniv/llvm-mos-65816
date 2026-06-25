// #321 beefy demo — fixed-point Mandelbrot escape-time kernel.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (k_mandel.c / the SNES
// display build) and the host PNG renderer (tools/mandel-render.c). Because both
// the host (int = 32-bit) and llvm-mos (int = 16-bit) compile THIS code, the result
// is bit-identical on every platform ONLY because every narrowing is an explicit
// fixed-width cast and every product is forced through int32_t. Do not "simplify"
// a cast away — it is load-bearing for the differential gate.
//
// Math: signed Q5.10 fixed point (1.0 == 1024, range +-32, resolution ~1/1024).
//   z_{n+1} = z_n^2 + c,  escape when |z|^2 > 4.  Escape count is the pixel value.
#ifndef MANDEL_H
#define MANDEL_H

#include <stdint.h>

#define MANDEL_Q       10            /* fractional bits: 1.0 == 1<<10 == 1024 */
#define MANDEL_ONE     (1 << MANDEL_Q)
#define MANDEL_RE0     (-2304)       /* -2.25 * 1024  (left edge, real)       */
#define MANDEL_IM0     (-1280)       /* -1.25 * 1024  (top edge,  imag)       */
#define MANDEL_REW     3072          /*  3.0  * 1024  (window width,  real)   */
#define MANDEL_IMW     2560          /*  2.5  * 1024  (window height, imag)   */
#define MANDEL_ESCAPE  (4 << MANDEL_Q) /* |z|^2 > 4.0 in Q5.10                */

// Escape count for one cell (cr, ci in Q5.10). The hot path: three 16x16->32
// fixed-point multiplies per iteration (zr^2, zi^2, zr*zi), holding zr/zi live
// across the loop — exactly the >1-live-16-bit-value pressure +mos-a16 targets.
//
// noinline (the k_prng.c / k_fxmul.c pattern): the 16-bit accumulator state crosses
// the call boundary every cell, so +mos-a16 must drop to 8-bit at the call and
// re-enter 16-bit inside — a realistic, idiomatic exercise. It is ALSO load-bearing:
// inlining mandel_cell into mandel_fill into main piles every loop's 16-bit live
// ranges together and overflows the imaginary-register file, which under the neutral
// `--target=mos` codegen path (no platform -mlto-zp budget) makes regalloc emit a
// COPY from an undefined $rc (a -verify-machineinstrs failure — same family as the
// known a16regpress issue, worse failure mode). See
// docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md "Finding" + the repro. Keeping
// the cell a real callee bounds the pressure; do not drop noinline.
__attribute__((noinline)) static uint8_t mandel_cell(int16_t cr, int16_t ci, uint8_t maxiter) {
  int16_t zr = 0, zi = 0;
  uint8_t n;
  for (n = 0; n < maxiter; n++) {
    // Products are int32; >> MANDEL_Q brings Q10.20 back to Q5.10. The (int32_t)
    // cast on one operand forces a 32-bit multiply on both host and target.
    int32_t zr2 = ((int32_t)zr * zr) >> MANDEL_Q;
    int32_t zi2 = ((int32_t)zi * zi) >> MANDEL_Q;
    if (zr2 + zi2 > MANDEL_ESCAPE) break;            /* escaped */
    // Held in int32 until the explicit (int16_t) narrowing wraps identically on
    // both platforms. When NOT escaped, |zr|,|zi| <= 2048, so these fit int16
    // exactly (no actual wrap) — the cast just pins the type.
    int16_t tmp = (int16_t)(zr2 - zi2 + cr);
    zi = (int16_t)(2 * (((int32_t)zr * zi) >> MANDEL_Q) + ci);
    zr = tmp;
  }
  return n;
}

// Fill a W*H row-major buffer (1 byte/pixel = escape count) for the Mandelbrot
// window. Window steps are DERIVED (dre = REW/w, dim = IMW/h) so host == target
// by construction at any grid size.
static inline void mandel_fill(uint8_t *fb, uint8_t w, uint8_t h, uint8_t maxiter) {
  int16_t dre = (int16_t)(MANDEL_REW / w);
  int16_t dim = (int16_t)(MANDEL_IMW / h);
  for (uint8_t j = 0; j < h; j++) {
    int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)j * dim);
    for (uint8_t i = 0; i < w; i++) {
      int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)i * dre);
      uint16_t idx = (uint16_t)((uint16_t)j * w + i);
      fb[idx] = mandel_cell(cr, ci, maxiter);
    }
  }
}

// 5-bit-per-channel palette (BGR555-ready) for escape count n; interior (n>=maxiter)
// is black. Shared so the host PNG (channels <<3 -> RGB888) and the on-console CGRAM
// (SNES_RGB(r,g,b)) render the SAME colours — letting the emulator screenshot be
// compared directly against the host reference.
static inline void mandel_palette(uint8_t n, uint8_t maxiter, uint8_t *r5, uint8_t *g5, uint8_t *b5) {
  if (n >= maxiter) { *r5 = 0; *g5 = 0; *b5 = 0; return; }
  uint8_t t = (uint8_t)((unsigned)n * 31u / (maxiter ? maxiter : 1));   // 0..31
  *r5 = t;
  *g5 = (uint8_t)((t < 16) ? (t * 2) : 31);
  *b5 = (uint8_t)(31 - t);
}

// CRC16-CCITT (XModem: poly 0x1021, init 0xFFFF, MSB-first, no reflection) over the
// whole buffer — the SAME promotion-safe routine as examples/65816/k_crc16.c (the
// "(uint16_t)x << 8" casts force unsigned-int promotion on the 16-bit-int target,
// avoiding signed-overflow UB, and re-truncate so host and target agree bit-for-bit).
// A CRC match proves the ENTIRE buffer is identical; a codegen bug corrupts many
// pixels, so a false pass is effectively impossible.
static inline uint16_t mandel_crc(const uint8_t *fb, uint16_t len) {
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

// Fast 16-bit rolling hash for verifying a BAKED asset round-trips (host-baked == read back on
// target) — NOT a CRC. The interactive demo bakes its image host-side, so the gate only needs to
// catch a corrupted/misread ROM array (which flips many bytes); a rotate-xor over 16 KiB is ~10x
// cheaper than mandel_crc's 8-shifts-per-byte, so it runs in a few frames at boot instead of
// stalling the demo. Promotion-safe: the (uint16_t) casts pin the width on the 16-bit-int target.
static inline uint16_t img_hash16(const uint8_t *p, uint16_t n) {
  uint16_t h = 0;
  for (uint16_t i = 0; i < n; i++) {
    // rotate-left-1 then xor the byte. Cast to `unsigned` BEFORE shifting: on the 16-bit-int
    // target, `h >> 15` would otherwise promote a >=0x8000 value to a NEGATIVE int and arithmetic-
    // shift to 0xFFFF (a host/target divergence the differential gate caught). `unsigned` keeps it
    // logical; the final (uint16_t) truncates the host's wider result to match the target's mod-2^16.
    unsigned hi = ((unsigned)h >> 15) & 1u;
    h = (uint16_t)((((unsigned)h << 1) | hi) ^ (unsigned)p[i]);
  }
  return h;
}

#endif /* MANDEL_H */
