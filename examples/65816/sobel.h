// Sobelscope (#87) — shared, portable logic header.
//
// Stresses: signed int16 multiply-accumulate (3x3 Sobel convolution) + SATURATING
// arithmetic via __builtin_elementwise_add_sat / _sub_sat → G_SADDSAT / G_USUBSAT.
// The Sobel kernels Gx/Gy are a signed weighted sum (MAC) over a 3x3 window; the edge
// magnitude |Gx|+|Gy| is combined with a SATURATING add so it clamps instead of wrapping.
// Distinct from #57 medfilt (min/max compare-exchange sorting network, NO MAC, no saturate).
//
// WIDTH DISCIPLINE: int16_t samples/accumulators, uint8_t magnitudes. No bare int.
// DIFFERENTIAL: exact integer MAC + saturating ops — bit-identical host vs 65816. Any wrong
// signed MAC, or a saturating-add that wraps instead of clamping, diverges the edge fold.
//
// See docs/plans/2026-07-01-87-snes-sobel.md.

#ifndef SOBEL_H
#define SOBEL_H

#include <stdint.h>

#define SB_W       32u                   // source field width
#define SB_H       32u                   // source field height
#ifndef SB_GATE_N
#define SB_GATE_N  1u                    // one full-field Sobel pass per phase in the gate
#endif

// Procedural source image: a signed pattern with edges (concentric + diagonal steps).
// phase animates it. Values in roughly [-120, 120].
static inline int16_t sb_src(int16_t x, int16_t y, int16_t phase) {
    int16_t dx = (int16_t)(x - (int16_t)(SB_W / 2u));
    int16_t dy = (int16_t)(y - (int16_t)(SB_H / 2u));
    int16_t r2 = (int16_t)((int16_t)(dx * dx) + (int16_t)(dy * dy));   // small (<= 512)
    // ring pattern (step edges) + a diagonal ramp, animated by phase
    int16_t ring = (int16_t)(((r2 + phase) >> 3) & 1) ? (int16_t)100 : (int16_t)(-100);
    int16_t diag = (int16_t)((((x + y + phase) >> 2) & 1) ? (int16_t)20 : (int16_t)(-20));
    return (int16_t)(ring + diag);
}

// Saturating helpers (the codegen corner). On clang (the 65816 target toolchain) these use
// __builtin_elementwise_add_sat/_sub_sat → G_SADDSAT / G_USUBSAT. On the host oracle (gcc,
// which lacks those builtins) a bit-identical manual fallback computes the same result, so the
// differential stays meaningful: the TARGET exercises the saturating-intrinsic path.
#if defined(__clang__)
static inline int16_t sb_add_sat(int16_t a, int16_t b) {
    return __builtin_elementwise_add_sat(a, b);     // G_SADDSAT
}
static inline uint8_t sb_sub_sat_u8(uint8_t a, uint8_t b) {
    return __builtin_elementwise_sub_sat(a, b);     // G_USUBSAT
}
#else
static inline int16_t sb_add_sat(int16_t a, int16_t b) {
    int32_t s = (int32_t)a + (int32_t)b;
    if (s > 32767) s = 32767;
    if (s < -32768) s = -32768;
    return (int16_t)s;
}
static inline uint8_t sb_sub_sat_u8(uint8_t a, uint8_t b) {
    return (uint8_t)(a > b ? (uint8_t)(a - b) : 0u);
}
#endif

// Signed 3x3 Sobel at (x,y): Gx/Gy MAC, magnitude via saturating add, clamped to 0..255.
static inline uint8_t sb_edge(int16_t x, int16_t y, int16_t phase) {
    int16_t s00 = sb_src((int16_t)(x-1), (int16_t)(y-1), phase);
    int16_t s01 = sb_src((int16_t)(x  ), (int16_t)(y-1), phase);
    int16_t s02 = sb_src((int16_t)(x+1), (int16_t)(y-1), phase);
    int16_t s10 = sb_src((int16_t)(x-1), (int16_t)(y  ), phase);
    int16_t s12 = sb_src((int16_t)(x+1), (int16_t)(y  ), phase);
    int16_t s20 = sb_src((int16_t)(x-1), (int16_t)(y+1), phase);
    int16_t s21 = sb_src((int16_t)(x  ), (int16_t)(y+1), phase);
    int16_t s22 = sb_src((int16_t)(x+1), (int16_t)(y+1), phase);
    // Gx = [-1 0 1; -2 0 2; -1 0 1] · window  (signed MAC)
    int16_t gx = (int16_t)((int16_t)(s02 - s00) + (int16_t)((int16_t)(2*s12) - (int16_t)(2*s10)) + (int16_t)(s22 - s20));
    int16_t gy = (int16_t)((int16_t)(s20 - s00) + (int16_t)((int16_t)(2*s21) - (int16_t)(2*s01)) + (int16_t)(s22 - s02));
    int16_t ax = (int16_t)(gx < 0 ? -gx : gx);
    int16_t ay = (int16_t)(gy < 0 ? -gy : gy);
    // saturating magnitude: |Gx| +sat |Gy|, then scale down and saturate-subtract a floor
    int16_t mag = sb_add_sat(ax, ay);                       // G_SADDSAT (clamps at +32767)
    uint8_t m8 = (uint8_t)((mag >> 1) > 255 ? 255 : (uint8_t)(mag >> 1));
    return sb_sub_sat_u8(m8, (uint8_t)16u);                 // G_USUBSAT (floor without underflow)
}

// ------------------------------------------------------------------
// Gate CRC: sweep the field, fold every edge magnitude across GATE_N phases.
// ------------------------------------------------------------------
static uint16_t sobel_gate_crc(void) {
    uint16_t h = 0u;
    int16_t phase;
    for (phase = 0; phase < (int16_t)((int16_t)SB_GATE_N * 4); phase = (int16_t)(phase + 4)) {
        int16_t y, x;
        for (y = 1; y < (int16_t)(SB_H - 1u); y++) {
            for (x = 1; x < (int16_t)(SB_W - 1u); x++) {
                uint8_t e = sb_edge(x, y, phase);
                h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
                h = (uint16_t)(h ^ (uint16_t)((uint16_t)e * 97u));
            }
        }
    }
    return h;
}

#endif /* SOBEL_H */
