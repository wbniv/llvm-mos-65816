// Shared, PURE union type-pun fast-inverse-sqrt — host-linkable, no hardware.  Demo #45.
//
// The codegen corner: **union type-punning** — the Quake `union { float f; uint32_t i; }` bit hack that
// reads a float's storage AS an integer, mangles the bits, and reads it back AS a float.  The aliased
// load/store + float<->int bit reinterpret is the path under test.  It drives a fast reciprocal-sqrt
// (`1/sqrt(x)`) that a field of metaballs uses for its `1/dist` falloff.
//
// Width + soft-float discipline (host must match target byte-for-byte):
//   - the pun is uint32_t <-> float (both little-endian on host and 65816 -> identical reinterpret)
//   - float ops are ONE PER STATEMENT so the target never FMA-fuses a multiply-add the host computes
//     as two rounded ops (see the soft-float bit-exact differential note); the fold masks to uint16_t
// See docs/plans/2026-06-30-45-snes-metaball.md.
#ifndef METABALL_H
#define METABALL_H

#include <stdint.h>

union fu { float f; uint32_t i; };

// Quake III fast inverse square root, union-punned, one float op per statement (no FMA fusion).
static float q_rsqrt(float number) {
    union fu u;
    float x2 = number * 0.5f;
    u.f = number;                          // store as float
    uint32_t bits = u.i;                   // read the SAME storage as uint32 (type-pun)
    bits = bits >> 1;
    bits = (uint32_t)(0x5f3759dfu - bits); // the magic constant
    u.i = bits;                            // store as uint32
    float y = u.f;                         // read it back as float (type-pun)
    float yy = y * y;                      // one Newton-Raphson refinement, split per statement:
    float t  = x2 * yy;
    float s  = 1.5f - t;
    float r  = y * s;
    return r;
}

// Metaball field intensity at (x,y): sum of 1/dist falloff from NB blob centres (fixed-point in, float
// out).  Uses q_rsqrt on the squared distance -> 1/dist.  Kept one-op-per-statement.
#define MB_NB 4

static float mb_field(int16_t x, int16_t y, const int16_t *bx, const int16_t *by) {
    float acc = 0.0f;
    for (uint8_t k = 0; k < MB_NB; k++) {
        int16_t dx = (int16_t)(x - bx[k]);
        int16_t dy = (int16_t)(y - by[k]);
        int32_t d2 = (int32_t)dx * (int32_t)dx;
        int32_t e2 = (int32_t)dy * (int32_t)dy;
        int32_t s2 = d2 + e2;
        if (s2 < 1) s2 = 1;
        float fs = (float)s2;
        float inv = q_rsqrt(fs);           // 1/dist  (union type-pun inside)
        acc = acc + inv;
    }
    acc = acc * 18.0f;                      // blob radius scale (visual only; gate uses q_rsqrt directly)
    return acc;
}

// ---------------------------------------------------------------------------------------------
// Differential gate: fold the raw float bits of q_rsqrt over a deterministic input sweep.

static inline uint16_t mb_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 48u
#endif

static uint16_t metaball_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 1; i <= (uint16_t)GATE_N; i++) {
        float x = (float)i;
        float r = q_rsqrt(x);
        union fu u;
        u.f = r;                           // pun the result float back to bits for hashing
        h = mb_fold(h, (uint16_t)u.i);
        h = mb_fold(h, (uint16_t)(u.i >> 16));
    }
    return h;
}

#endif /* METABALL_H */
