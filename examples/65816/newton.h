/* examples/65816/newton.h — Newton's-method fractal math, shared header.
 * f(z) = z³−1; f′(z) = 3z²; iteration: z ← z − f(z)/f′(z).
 * Three roots: z₁=1, z₂=e^(2πi/3), z₃=e^(4πi/3).
 * Pure C99/<stdint.h>; compiles on host (32-bit int) AND SNES (+mos-a16, 16-bit int).
 * Codegen stress: __divsi3 (complex division) + __mulsi3 (four muls/step) + rep/sep.
 * See docs/plans/2026-06-27-2-snes-newton-fractal.md                                */
#ifndef NEWTON_H
#define NEWTON_H

#include <stdint.h>

/* Q8.8 fixed-point: 1.0 = 256, range ≈ [−128, 128). View: [−2,2]×[−1.70,1.68].
 * EPS = 0.125 → threshold 32 in Q8.8 → EPS_SQ = 32² = 1024.                      */
#define NWT_SCALE    ((int16_t)256)
#define NWT_MAX_ITER 20
#define NWT_EPS_SQ   ((int32_t)1024)

/* Root coordinates in Q8.8:
 *   Root 1:  1 + 0i           → (256,   0)
 *   Root 2: −½ + (√3/2)i     → (−128, 222)
 *   Root 3: −½ − (√3/2)i     → (−128,−222)  */
#define NWT_R1_RE  ((int16_t) 256)
#define NWT_R1_IM  ((int16_t)   0)
#define NWT_R2_RE  ((int16_t)-128)
#define NWT_R2_IM  ((int16_t) 222)
#define NWT_R3_RE  ((int16_t)-128)
#define NWT_R3_IM  ((int16_t)-222)

/* Gate: 8×8 sample grid in [−1.2, 1.2]² (covers all three basins).
 * Step = 2.4/7 × 256 ≈ 87.8 → 88; start = −1.2 × 256 ≈ −307.               */
#define NEWTON_GATE_GW    8
#define NEWTON_GATE_GH    8
#define NEWTON_GATE_STEP  ((int16_t)88)
#define NEWTON_GATE_START ((int16_t)-307)

/* One Newton step: z ← z − (z³−1)/(3z²) in Q8.8.
 * Stresses: __mulsi3 (×4: z² and z³), __divsi3 (complex division).
 * Pre-scales num/denom by >>1 each so num·denom·256 stays inside int32_t.        */
static __attribute__((noinline)) void newton_step(int16_t *zr, int16_t *zi) {
    int16_t r = *zr, i = *zi;
    /* z² = (r²−i², 2ri) in Q8.8 */
    int16_t z2r = (int16_t)(((int32_t)r * (int32_t)r - (int32_t)i * (int32_t)i) >> 8);
    int16_t z2i = (int16_t)(((int32_t)r * (int32_t)i) >> 7);   /* 2ri >> 8 = ri >> 7 */
    /* z³ = z²·z in Q8.8 */
    int16_t z3r = (int16_t)(((int32_t)z2r * (int32_t)r - (int32_t)z2i * (int32_t)i) >> 8);
    int16_t z3i = (int16_t)(((int32_t)z2r * (int32_t)i + (int32_t)z2i * (int32_t)r) >> 8);
    /* Numerator: z³−1; denominator: 3z² (3×1024 = 3072 ≤ 32767 so int16_t safe) */
    int16_t nr = (int16_t)(z3r - NWT_SCALE);
    int16_t ni = z3i;
    int16_t dr = (int16_t)(3 * (int32_t)z2r);
    int16_t di = (int16_t)(3 * (int32_t)z2i);
    /* Scale by >>1 each before product to keep (scaled_num << 8) inside int32_t.
     * Max: |scaled_num| ≤ 1152×1536 = 1.77M; ×256 = 453M < 2.1B = INT32_MAX ✓ */
    int32_t snr = (int32_t)nr >> 1, sni = (int32_t)ni >> 1;
    int32_t sdr = (int32_t)dr >> 1, sdi = (int32_t)di >> 1;
    int32_t den = sdr * sdr + sdi * sdi;
    if (den == 0) return;   /* degenerate: z ≈ 0, skip */
    /* Complex division q = numerator/denominator in Q8.8; __divsi3 here */
    int32_t qr = ((snr * sdr + sni * sdi) << 8) / den;
    int32_t qi = ((sni * sdr - snr * sdi) << 8) / den;
    /* Clamp step to ±2.0 to prevent runaway near the denominator singularity */
    if (qr >  512) qr =  512;
    if (qr < -512) qr = -512;
    if (qi >  512) qi =  512;
    if (qi < -512) qi = -512;
    *zr = (int16_t)(r - (int16_t)qr);
    *zi = (int16_t)(i - (int16_t)qi);
}

/* Returns 1/2/3 if z is within NWT_EPS of root 1/2/3, else 0. */
static int8_t newton_nearest_root(int16_t zr, int16_t zi) {
    int32_t dr1 = (int32_t)(zr - NWT_R1_RE);
    int32_t di1 = (int32_t)(zi - NWT_R1_IM);
    if (dr1 * dr1 + di1 * di1 < NWT_EPS_SQ) return 1;
    int32_t dr23 = (int32_t)(zr - NWT_R2_RE);   /* zr + 128 */
    int32_t a23  = dr23 * dr23;
    int32_t dim2 = (int32_t)(zi - NWT_R2_IM);   /* zi − 222 */
    int32_t dim3 = (int32_t)(zi - NWT_R3_IM);   /* zi + 222 */
    if (a23 + dim2 * dim2 < NWT_EPS_SQ) return 2;
    if (a23 + dim3 * dim3 < NWT_EPS_SQ) return 3;
    return 0;
}

/* Gate CRC: fold 8×8=64 Newton evaluations into uint16_t (same value host and SNES). */
static __attribute__((noinline)) uint16_t newton_gate_crc(void) {
    uint16_t h = 0;
    int16_t zi0 = (int16_t)(-NEWTON_GATE_START);  /* +307 ≈ +1.2 (top of grid) */
    for (uint8_t gy = 0; gy < NEWTON_GATE_GH; gy++) {
        int16_t zr0 = NEWTON_GATE_START;            /* −307 ≈ −1.2 (left of grid) */
        for (uint8_t gx = 0; gx < NEWTON_GATE_GW; gx++) {
            int16_t zr = zr0, zi = zi0;
            int8_t root = newton_nearest_root(zr, zi);
            uint8_t iters = 0;
            while (!root && iters < NWT_MAX_ITER) {
                newton_step(&zr, &zi);
                iters++;
                root = newton_nearest_root(zr, zi);
            }
            /* Fold: rotating-shift XOR of (root×16 + iters_capped) */
            uint16_t v = (uint16_t)((uint8_t)root * 16u
                                    + (uint16_t)(iters < 15u ? iters : 15u));
            h = (uint16_t)((h << 1) | (h >> 15));
            h = (uint16_t)(h ^ v);
            zr0 = (int16_t)(zr0 + NEWTON_GATE_STEP);
        }
        zi0 = (int16_t)(zi0 - NEWTON_GATE_STEP);
    }
    return h;
}

#endif /* NEWTON_H */
