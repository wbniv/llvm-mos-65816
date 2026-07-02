// Matrix Cascade (#91) — shared, portable logic header.
//
// Stresses: the sret HIDDEN-POINTER struct-return ABI. A mat2 { int16_t a,b,c,d; } is 8 bytes
// (64-bit) — over the getNaturalAlignIndirect threshold (MOS.cpp:88) — so returning one by value
// forces the compiler to pass a hidden pointer to caller-allocated result storage (sret), rather
// than a register pair. mat_mul TAKES and RETURNS mat2 by value, and the cascade chains those
// returns: m = mul(mul(m, R), R)... Distinct from #26 boids (vec2 = 32-bit register-pair return,
// NOT sret) — this crosses the indirect-return threshold.
//
// WIDTH DISCIPLINE: int16_t matrix elements, int32_t products. No bare int.
// DIFFERENTIAL: exact Q8 fixed-point matrix algebra — bit-identical host vs 65816. Any wrong
// sret pointer, missed store, or aliasing of the result buffer diverges the cascade fold.
//
// See docs/plans/2026-07-01-91-snes-matcascade.md.

#ifndef MATCASCADE_H
#define MATCASCADE_H

#include <stdint.h>

#define MC_Q 8                       // Q8 fixed point
#ifndef MC_GATE_N
#define MC_GATE_N 48u                // matrices multiplied in the cascade
#endif

// 2x2 matrix, 8 bytes — over the sret threshold, so returned via hidden pointer.
typedef struct { int16_t a, b, c, d; } mat2;

// mat2 multiply, BY VALUE in and out (the sret ABI under test). __mulsi3 for the 16x16->32 MACs.
__attribute__((noinline))
static mat2 mat_mul(mat2 x, mat2 y) {
    mat2 r;
    r.a = (int16_t)(((int32_t)x.a * y.a + (int32_t)x.b * y.c) >> MC_Q);
    r.b = (int16_t)(((int32_t)x.a * y.b + (int32_t)x.b * y.d) >> MC_Q);
    r.c = (int16_t)(((int32_t)x.c * y.a + (int32_t)x.d * y.c) >> MC_Q);
    r.d = (int16_t)(((int32_t)x.c * y.b + (int32_t)x.d * y.d) >> MC_Q);
    return r;                        // sret: written through the hidden result pointer
}

// A small Q8 rotation-ish matrix (integer, deterministic).
static inline mat2 mc_rot(int16_t k) {
    // cos/sin from a tiny 8-entry Q8 LUT indexed by k&7
    static const int16_t C[8] = { 256, 181, 0, -181, -256, -181, 0, 181 };
    mat2 m;
    m.a = C[(uint8_t)(k & 7)];
    m.b = (int16_t)(-C[(uint8_t)((k + 2) & 7)]);
    m.c = C[(uint8_t)((k + 2) & 7)];
    m.d = C[(uint8_t)(k & 7)];
    return m;
}

// ------------------------------------------------------------------
// Gate CRC: chain GATE_N mat_muls (m = mul(m, rot(k))), fold the result elements.
// Every step passes/returns mat2 by value → the sret path runs GATE_N times.
// ------------------------------------------------------------------
static uint16_t matcascade_gate_crc(void) {
    mat2 m; m.a = 256; m.b = 0; m.c = 0; m.d = 256;   // identity (Q8)
    uint16_t h = 0u;
    uint16_t k;
    for (k = 0u; k < (uint16_t)MC_GATE_N; k++) {
        m = mat_mul(m, mc_rot((int16_t)k));            // chained by-value return (sret)
        // renormalize to keep magnitudes bounded (still exact integer)
        if (m.a > 4096 || m.a < -4096) { m.a >>= 2; m.b >>= 2; m.c >>= 2; m.d >>= 2; }
        h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
        h = (uint16_t)(h ^ (uint16_t)((int16_t)m.a * 97) ^ (uint16_t)((int16_t)m.b * 13)
                          ^ (uint16_t)((int16_t)m.c * 7)  ^ (uint16_t)((int16_t)m.d * 3));
    }
    return h;
}

// Transform a 2D point by a Q8 mat2 (for the ROM's wireframe).
static inline void mc_xform(mat2 m, int16_t x, int16_t y, int16_t *ox, int16_t *oy) {
    *ox = (int16_t)(((int32_t)m.a * x + (int32_t)m.b * y) >> MC_Q);
    *oy = (int16_t)(((int32_t)m.c * x + (int32_t)m.d * y) >> MC_Q);
}

#endif /* MATCASCADE_H */
