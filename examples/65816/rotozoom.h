// Shared, PURE affine texture rotate-zoom (rotozoom) — host-linkable, no hardware.  Demo #56.
//
// The codegen corner: **widening multiply-high**.  The Q16.16 fixed-point multiply q16mul(a,b) =
// (int64)a*b >> 16 keeps the middle 32 bits of a 64-bit product — the "take the high part of a wide
// product" pattern the generic opcode G_SMULH/G_UMULH models (MOSLegalizerInfo.cpp:300 `.lower()` =
// extend -> mul -> shift -> trunc).  MEASURED: on this soft-multiply target the widening goes through
// __muldi3 (32x32->64), and a 16x16->hi16 form goes through __mulsi3 — the `.lower()` expansion, since
// the multiply itself is a libcall (there is no narrower mul-high instruction).  Distinct from #22
// (avalanche) which used __muldi3 for a FULL 64-bit hash; here it is the mul-high EXTRACTION in a
// per-pixel affine sampler.
//
// WIDTH DISCIPLINE: the intermediate is an explicit int64; a,b are int32.  Both are the same width on
// host and target, and both gcc and clang arithmetic-shift a signed >>, so the differential is exact.
// See docs/plans/2026-06-30-56-snes-rotozoom.md.
#ifndef ROTOZOOM_H
#define ROTOZOOM_H

#include <stdint.h>
#include "../snes/sincos.h"       // SINCOS[256] = round(256*sin(2*pi*a/256)), Q8.8

#define ROTO_COS(a) SINCOS[(uint8_t)((a) + 64u)]
#define ROTO_SIN(a) SINCOS[(uint8_t)(a)]

#ifndef ROTO_TEX_BITS
#define ROTO_TEX_BITS 6u          // 64x64 texture (wrap mask 63)
#endif
#define ROTO_TEX_MASK ((1u << ROTO_TEX_BITS) - 1u)

// Q16.16 fixed-point multiply: the widening multiply-high (keep the middle 32 of a 64-bit product).
static inline int32_t q16mul(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * (int64_t)b) >> 16);
}

// Affine sample: texel coords (tx,ty) for cell (cx,cy) in [0,16) under rotation angle a (0..255),
// zoom (Q8.8), and centre texel (u0,v0) in Q16.16.  Each texel coord is two widening multiply-highs.
static inline void rotozoom_uv(uint8_t cx, uint8_t cy, uint8_t a, uint16_t zoom,
                               int32_t u0, int32_t v0, uint8_t *tx, uint8_t *ty) {
    int32_t co = (int32_t)ROTO_COS(a) * (int32_t)zoom;   // Q8.8 * Q8.8 = Q16.16
    int32_t si = (int32_t)ROTO_SIN(a) * (int32_t)zoom;
    int32_t dx = (int32_t)((int16_t)cx - 8) << 16;       // Q16.16 centred cell offset
    int32_t dy = (int32_t)((int16_t)cy - 8) << 16;
    int32_t u = q16mul(dx, co) - q16mul(dy, si) + u0;    // <- widening multiply-high
    int32_t v = q16mul(dx, si) + q16mul(dy, co) + v0;
    *tx = (uint8_t)((uint32_t)(u >> 16) & ROTO_TEX_MASK);
    *ty = (uint8_t)((uint32_t)(v >> 16) & ROTO_TEX_MASK);
}

// Procedural 64x64 texture -> colour 0..3 (checker + grid lines, so rotation/zoom is legible).
static inline uint8_t rotozoom_tex(uint8_t tx, uint8_t ty) {
    uint8_t checker = (uint8_t)(((tx >> 3) ^ (ty >> 3)) & 1u);
    uint8_t line    = (uint8_t)(((tx & 7u) == 0u) || ((ty & 7u) == 0u));
    return (uint8_t)(checker ? (line ? 3u : 2u) : (line ? 1u : 0u));
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t roto_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 100u          // heavy: each iter is ~18 __muldi3 (64-bit widening); keep the gate < ~600 frames
#endif

// Fold sampled texels and raw q16mul results over GATE_N frames.  A miscompile in the widening
// multiply-high (the extend/mul/shift/trunc lowering) diverges.
static uint16_t rotozoom_gate_crc(void) {
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        uint8_t a = (uint8_t)i;
        uint16_t zoom = (uint16_t)(200u + (i & 127u));       // Q8.8 ~0.78 .. 1.28
        int32_t u0 = (int32_t)32 << 16, v0 = (int32_t)24 << 16;
        for (uint8_t k = 0u; k < 4u; k++) {
            uint8_t cx = (uint8_t)((i + (uint16_t)k * 3u) & 15u);
            uint8_t cy = (uint8_t)(((uint16_t)i * 2u + k) & 15u);
            uint8_t tx, ty;
            rotozoom_uv(cx, cy, a, zoom, u0, v0, &tx, &ty);
            h = roto_fold(h, (uint16_t)(((uint16_t)tx << 8) | ty));
            h = roto_fold(h, (uint16_t)rotozoom_tex(tx, ty));
        }
        // directly fold two raw widening multiply-highs (signed and larger-magnitude)
        h = roto_fold(h, (uint16_t)(q16mul((int32_t)((int16_t)i - 100) << 16,
                                           (int32_t)ROTO_COS(a) * 300) & 0xFFFFu));
        h = roto_fold(h, (uint16_t)((uint32_t)q16mul((int32_t)i << 12,
                                           (int32_t)ROTO_SIN(a) * (int32_t)zoom) >> 4));
    }
    return h;
}

#endif /* ROTOZOOM_H */
