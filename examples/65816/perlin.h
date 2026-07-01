// Shared, PURE fixed-point Perlin gradient noise — host-linkable, no hardware.  Demo #68.
//
// The codegen corner: **gradient (Perlin) noise** — a permutation table + the Hermite quintic **fade
// polynomial** 6t^5 - 15t^4 + 10t^3 + gradient **dot products** + **lerp**, all in fixed point.  Nothing
// in the first 67 demos runs the perm-index + fade-polynomial + dot-of-gradients + interpolation
// pipeline (value-noise/plasma/CA never did gradient noise).  The fade polynomial and lerps are a
// multiply-add-heavy fixed-point kernel; being header-shipped and integer, it is bit-exact host vs target.
//
// Everything is fixed point (Q0.8 fractions, int32 intermediates) — no float, so no ULP concerns; the
// permutation is a seeded integer shuffle (identical host/target).  See docs/plans/2026-06-30-68-snes-perlin.md.
#ifndef PERLIN_H
#define PERLIN_H

#include <stdint.h>

static uint8_t PN_PERM[512];        // doubled permutation
static uint8_t pn_ready = 0u;

// Build the permutation: a Fisher-Yates shuffle of 0..255 with a fixed seed, then doubled.
static void pn_init(void) {
    for (uint16_t i = 0u; i < 256u; i++) PN_PERM[i] = (uint8_t)i;
    uint16_t s = 0x2A6Du;
    for (uint16_t i = 255u; i > 0u; i--) {
        s ^= (uint16_t)(s << 7); s ^= (uint16_t)(s >> 9); s ^= (uint16_t)(s << 8);
        uint16_t j = (uint16_t)(s % (i + 1u));
        uint8_t t = PN_PERM[i]; PN_PERM[i] = PN_PERM[j]; PN_PERM[j] = t;
    }
    for (uint16_t i = 0u; i < 256u; i++) PN_PERM[256u + i] = PN_PERM[i];
    pn_ready = 1u;
}

// The Hermite quintic fade, computed INLINE in Q0.8: t in [0,256] -> 6u^5-15u^4+10u^3, u=t/256, in Q0.8.
static int32_t pn_fade(int32_t t) {
    int32_t t2 = (t * t) >> 8;                 // u^2  Q0.8
    int32_t t3 = (t2 * t) >> 8;                // u^3  Q0.8
    int32_t a = 6 * t - 3840;                  // (6u - 15)  Q0.8   (15*256 = 3840)
    int32_t b = ((a * t) >> 8) + 2560;         // u(6u-15) + 10  Q0.8   (10*256 = 2560)
    return (t3 * b) >> 8;                       // u^3 * [...]  Q0.8
}

// Gradient dot product: pick one of 4 diagonal gradients by hash, dot with (xf,yf) (Q0.8 signed).
static int32_t pn_grad(uint8_t hash, int32_t xf, int32_t yf) {
    switch (hash & 3u) {
        case 0:  return  xf + yf;
        case 1:  return -xf + yf;
        case 2:  return  xf - yf;
        default: return -xf - yf;
    }
}

static inline int32_t pn_lerp(int32_t a, int32_t b, int32_t t) {   // t in Q0.8
    return a + (((b - a) * t) >> 8);
}

// 2-D Perlin noise at (x,y) in Q8.8; returns Q?.8 (roughly [-512,512]).
static int32_t pn_noise(int32_t x, int32_t y) {
    int32_t xi = (x >> 8) & 255, yi = (y >> 8) & 255;
    int32_t xf = x & 255, yf = y & 255;                    // Q0.8 [0,256)
    int32_t u = pn_fade(xf), v = pn_fade(yf);
    uint8_t aa = PN_PERM[(uint16_t)(PN_PERM[(uint16_t)xi] + yi)];
    uint8_t ab = PN_PERM[(uint16_t)(PN_PERM[(uint16_t)xi] + yi + 1u)];
    uint8_t ba = PN_PERM[(uint16_t)(PN_PERM[(uint16_t)(xi + 1u)] + yi)];
    uint8_t bb = PN_PERM[(uint16_t)(PN_PERM[(uint16_t)(xi + 1u)] + yi + 1u)];
    int32_t x1 = pn_lerp(pn_grad(aa, xf, yf),        pn_grad(ba, xf - 256, yf),        u);
    int32_t x2 = pn_lerp(pn_grad(ab, xf, yf - 256),  pn_grad(bb, xf - 256, yf - 256),  u);
    return pn_lerp(x1, x2, v);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t pn_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 120u
#endif

// Fold pn_noise over a grid of sample points (at a fractional scale so the fade + gradients + lerp all
// fire), plus pn_fade directly across [0,256].  A miscompile in the polynomial, dot, lerp, or the
// permutation indexing diverges.
static uint16_t perlin_gate_crc(void) {
    if (!pn_ready) pn_init();
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        int32_t x = (int32_t)(i * 96u);            // Q8.8, ~0.375 step
        int32_t y = (int32_t)(i * 53u + 128u);
        int32_t n = pn_noise(x, y);
        h = pn_fold(h, (uint16_t)(n & 0xFFFF));
        h = pn_fold(h, (uint16_t)(pn_fade((int32_t)(i & 0xFFu)) & 0xFFFF));
    }
    return h;
}

#endif /* PERLIN_H */
