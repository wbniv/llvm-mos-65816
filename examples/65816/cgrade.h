// Shared, PURE many-argument color-grade kernel — host-linkable, no hardware.  Demo #50.
//
// The codegen corner: **>register-count argument spilling** in the calling convention.  color_grade()
// takes TEN int16 parameters (a base value + 9 grade coefficients: 3 lifts, 3 gammas, gain, mix, bias),
// which overflow the register-argument budget and force the extras **onto the soft stack**.  The callee
// must load those spilled args back off the frame; noinline keeps the call real (no inlining folds the
// args away).  A per-cell color grade sweeps the coefficients over time.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - params/results are int16_t; the accumulator is int32_t (explicit casts on every product/sum);
//     the fold masks to uint16_t.
// See docs/plans/2026-06-30-50-snes-cgrade.md.
#ifndef CGRADE_H
#define CGRADE_H

#include <stdint.h>

// Ten-argument color grade: base v, lifts a/b/c, gammas d/e/f, gain g, mix h, bias i.  Every argument
// is used so none is eliminated; the last several spill onto the soft stack.  noinline: force the ABI.
__attribute__((noinline))
static int16_t color_grade(int16_t v, int16_t a, int16_t b, int16_t c,
                           int16_t d, int16_t e, int16_t f,
                           int16_t g, int16_t h, int16_t i) {
    int32_t acc = (int32_t)v * (int32_t)g;                 // gain
    acc = acc + (int32_t)a + (int32_t)b + (int32_t)c;      // lifts
    acc = acc + ((int32_t)d - (int32_t)e + (int32_t)f);    // gammas
    acc = acc + ((int32_t)h * (int32_t)i);                 // mix * bias
    acc = acc >> 3;
    return (int16_t)acc;
}

// ---------------------------------------------------------------------------------------------
// Differential gate: sweep the ten-argument grade and fold the results.

static inline uint16_t cg_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 100u
#endif

static uint16_t cgrade_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t k = 0; k < (uint16_t)GATE_N; k++) {
        int16_t v = (int16_t)(k * 3u + 7u);
        int16_t a = (int16_t)(k - 40);
        int16_t b = (int16_t)((k << 1) - 30);
        int16_t c = (int16_t)(50 - (int16_t)k);
        int16_t d = (int16_t)(k & 15u);
        int16_t e = (int16_t)((k >> 1) & 31u);
        int16_t f = (int16_t)(k % 7u);
        int16_t g = (int16_t)(2 + (k & 3u));
        int16_t hh = (int16_t)((int16_t)(k & 7u) - 3);
        int16_t ii = (int16_t)((k % 5u) + 1u);
        int16_t r = color_grade(v, a, b, c, d, e, f, g, hh, ii);   // 10-arg call (spills)
        h = cg_fold(h, (uint16_t)r);
    }
    return h;
}

#endif /* CGRADE_H */
