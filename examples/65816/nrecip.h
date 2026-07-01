// Shared, PURE Newton-Raphson fixed-point reciprocal — host-linkable, no hardware.  Demo #47.
//
// The codegen corner: **iterative fixed-point refinement** — a MULTIPLY-ONLY Newton-Raphson reciprocal
// (1/m) with no hardware divide and no divide libcall.  The iteration x_{n+1} = x_n * (2 - m*x_n)
// converges quadratically to 1/m; each step is two Q15 multiplies (32-bit __mulsi3) and a subtract.
// Distinct from a single divide libcall (#39) and from #45's float bit-hack: this is a convergent
// INTEGER fixed-point loop.  A perspective floor uses the reciprocal for its 1/z depth mapping.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - all math is explicit uint32_t Q15 fixed-point (m,x in Q15); products fit uint32 (no uint64,
//     no float, no divide) so host and target compute identical bits; the fold masks to uint16_t.
// See docs/plans/2026-06-30-47-snes-nrecip.md.
#ifndef NRECIP_H
#define NRECIP_H

#include <stdint.h>

#define NR_Q     15u                 // Q15 fixed point (1.0 == 1<<15)
#define NR_ONE   (1uL << NR_Q)        // 32768
#define NR_TWO   (2uL << NR_Q)        // 65536

// Reciprocal of a normalized mantissa m in [0.5, 1.0)  (Q15: [16384, 32768)).  Returns 1/m in (1,2]
// as Q15.  Multiply-only Newton: linear seed then 4 refinements.  All products fit uint32.
static uint32_t nr_recip_mant(uint32_t m) {
    // Linear initial guess x0 = 48/17 - 32/17 * m  (the classic Newton-Raphson reciprocal seed).
    uint32_t x = (uint32_t)(92505uL - ((61681uL * m) >> NR_Q));   // Q15
    for (uint8_t i = 0; i < 4u; i++) {
        uint32_t t  = (uint32_t)(((uint32_t)m * x) >> NR_Q);      // m*x  (Q15)
        uint32_t tm = (uint32_t)(NR_TWO - t);                    // 2 - m*x  (Q15)
        x = (uint32_t)(((uint32_t)x * tm) >> NR_Q);              // x*(2 - m*x)  (Q15)
    }
    return x;
}

// Reciprocal of an arbitrary z in [1, 65535]: normalize z left until its MSB sits at bit 15
// (m = z<<s in [32768,65536)), recip the mantissa, then shift back.  Returns Q16 of 1/z.
static uint32_t nr_recip(uint16_t z) {
    if (z == 0u) return 0u;
    uint32_t m = z;
    uint8_t s = 0u;
    while (m < 32768uL) { m <<= 1; s++; }          // m = z<<s in [32768,65536)
    uint32_t r15 = nr_recip_mant((uint32_t)(m >> 1)); // 1/mantissa in Q15 (mant = m/65536 in [0.5,1))
    // 1/z (Q16) = r15 >> (15 - s), or r15 << (s - 15) when s > 15.
    if (s <= 15u) return (uint32_t)(r15 >> (15u - s));
    return (uint32_t)(r15 << (s - 15u));
}

// ---------------------------------------------------------------------------------------------
// Differential gate: fold the Newton reciprocal over a deterministic sweep of mantissas + z values.

static inline uint16_t nr_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 96u
#endif

static uint16_t nrecip_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_N; i++) {
        uint32_t m = (uint32_t)(16384u + ((uint32_t)i * 170u));   // sweep mantissa across [0.5,1)
        if (m >= NR_ONE) m = NR_ONE - 1u;
        uint32_t r = nr_recip_mant(m);
        h = nr_fold(h, (uint16_t)r);
        uint16_t z = (uint16_t)(i * 37u + 1u);                    // sweep arbitrary z
        uint32_t rz = nr_recip(z);
        h = nr_fold(h, (uint16_t)rz);
        h = nr_fold(h, (uint16_t)(rz >> 16));
    }
    return h;
}

#endif /* NRECIP_H */
