// Signed Multiply-Overflow Orbit Sentinel (#76) — shared, portable logic header.
//
// Stresses G_SMULO via __builtin_mul_overflow(a,b,ptr) on BOTH:
//   (1) int16_t a,b: G_SMULO at s16 -> lowerMulo (widen-multiply-sign-check)
//       Distinct from #44 hdr-bloom: G_UADDO add-overflow (carry/V branch)
//       Distinct from #56 rotozoom: G_UMULH/SMULH (keeps high half, no overflow check)
//   (2) int32_t a32,b32: G_SMULO at s32 -> lowerMulo widens int32->int64 -> __muldi3
//       (the widen-to-double-width path; __mulosi4 is the ACLE helper but LLVM lowerMulo
//        goes through int64 widening instead). First demo to use signed mul-overflow check.
//
// Algorithm: at each gate step i, compute two overflow-checked multiplications:
//   a = (int16_t)(i*7 + 3), b = (int16_t)(i*11 + 5)
//   p16, ov16 = smulo(a, b)     -- int16_t path
//   a32 = a * 256, b32 = b * 64
//   p32, ov32 = smulo(a32, b32) -- int32_t path -> __mulosi4
// Fold: accumulate ov_count, XOR p16 with (ov_count * 3) into CRC.
//
// GATE_N = 121 (not a multiple of 16 — avoids the rotate-period CRC cancellation).
// For i >= ~25: a*b exceeds INT16_MAX -> ov16=true.
// For i >= ~16: a32*b32 exceeds INT32_MAX -> ov32=true.
//
// WIDTH DISCIPLINE: all integer values uint16_t/int16_t/int32_t; no bare int; no float.
// DIFFERENTIAL: integer-exact — both paths are standard-defined signed overflow detection
// (result is the truncated product; overflow flag is 1 iff the true result doesn't fit);
// any wrong lowering (e.g. wrong sign-extension comparison) diverges the CRC immediately.
// See docs/plans/2026-07-01-76-snes-smulorbit.md.

#ifndef SMULORBIT_H
#define SMULORBIT_H

#include <stdint.h>
#include <stdbool.h>

// CRC fold step (rotating XOR).
static inline uint16_t so_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// --------------------------------------------------------------------------
// Differential gate: GATE_N steps with both int16 and int32 signed mul-overflow.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 121u
#endif

static uint16_t smulorbit_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    uint16_t ov_count = (uint16_t)0u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        // int16_t signed multiply-overflow (G_SMULO s16, lowerMulo)
        int16_t a  = (int16_t)((uint16_t)(i * (uint16_t)7u + (uint16_t)3u));
        int16_t b  = (int16_t)((uint16_t)(i * (uint16_t)11u + (uint16_t)5u));
        int16_t p16;
        bool ov16  = __builtin_mul_overflow(a, b, &p16);

        // int32_t signed multiply-overflow (G_SMULO s32 -> __mulosi4)
        int32_t a32 = (int32_t)a * (int32_t)256;
        int32_t b32 = (int32_t)b * (int32_t)64;
        int32_t p32;
        bool ov32   = __builtin_mul_overflow(a32, b32, &p32);

        if (ov16) ov_count++;
        if (ov32) ov_count++;
        uint16_t v  = (uint16_t)p16 ^ (uint16_t)((uint16_t)ov_count * (uint16_t)3u);
        h = so_fold(h, v);
    }
    return h;
}

// --------------------------------------------------------------------------
// Orbit state for the SNES ROM display.
// Each orbiter has a 2-D position (px,py) in [0..127] and a velocity (vx,vy).
// At each display step we try to scale vx by a growing factor using smulo;
// overflow causes a teleport to the mirror quadrant and a bright spark.
// --------------------------------------------------------------------------
typedef struct {
    uint8_t px, py;    // position in [0..127]
    int8_t  vx, vy;   // velocity in [-8..8]
    uint8_t spark;     // countdown for bright spark glow
} SOrbiter;

#define SO_N 6          // number of orbiters
#define SO_SPARK_TTL 12 // frames a spark glows for

// Initialise all orbiters from fixed seeds (deterministic).
static void so_init(SOrbiter orbs[SO_N]) {
    for (uint8_t i = 0u; i < (uint8_t)SO_N; i++) {
        orbs[i].px    = (uint8_t)(8u + (uint8_t)(i * (uint8_t)20u));
        orbs[i].py    = (uint8_t)(16u + (uint8_t)(i * (uint8_t)15u));
        orbs[i].vx    = (int8_t)(1 + (int8_t)((int8_t)(i & 3)));
        orbs[i].vy    = (int8_t)(1 + (int8_t)((int8_t)((i >> 1) & 3)));
        orbs[i].spark = 0u;
    }
}

// Step one orbiter; return the color to plot (1=dim, 2=medium, 3=spark).
// scale_factor grows with time to eventually trigger overflow.
static inline uint8_t so_step(SOrbiter *o, uint16_t t) {
    // Signed mul-overflow check: vx * scale_factor
    int16_t sf   = (int16_t)((uint16_t)(t >> 2) + (uint16_t)1u);  // 1..grows
    int16_t vx16 = (int16_t)o->vx;
    int16_t scaled;
    bool ov      = __builtin_mul_overflow(vx16, sf, &scaled);

    if (ov) {
        // Overflow: teleport to mirror quadrant + reverse direction
        o->px    = (uint8_t)((uint8_t)127u - o->px);
        o->py    = (uint8_t)((uint8_t)127u - o->py);
        o->vx    = (int8_t)(-(int8_t)o->vx);
        o->vy    = (int8_t)(-(int8_t)o->vy);
        o->spark = (uint8_t)SO_SPARK_TTL;
        return (uint8_t)3u;   // bright spark
    }
    // Normal step: move by clamped scaled velocity (int8_t truncation)
    o->px = (uint8_t)((uint8_t)((uint8_t)(o->px) + (int8_t)scaled) & (uint8_t)127u);
    o->py = (uint8_t)((uint8_t)((uint8_t)(o->py) + (uint8_t)o->vy) & (uint8_t)127u);
    if (o->spark > (uint8_t)0u) o->spark--;
    return (o->spark > (uint8_t)0u) ? (uint8_t)2u : (uint8_t)1u;
}

#endif /* SMULORBIT_H */
