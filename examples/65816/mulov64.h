// 64-bit Multiply-Overflow / Multiply-High Sentinel (#101) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster C, first pick — THE sharp probe from the 2026-07-02
// coverage check of MOSLegalizerInfo.cpp. Stresses the ONE untested s64 legalizer path:
//
//   __builtin_mul_overflow on uint64_t/int64_t -> G_UMULO/G_SMULO at s64 (.lower() @301)
//     -> LegalizerHelper::lowerMulo computes the FULL product; its high 64 bits need
//        G_UMULH/G_SMULH at s64 (.lower() @312).
//   The s64 mulh .lower() CANNOT widen to s128: G_MUL is clampScalar(0,S8,S32) @237, with the
//   comment "Lowering S128 to S64 would produce infinite regress ... so instead it's lowered to
//   S32" @231. So the 128-bit product must be composed from s32 (__mulsi3) pieces + s64 (__muldi3)
//   glue — a delicate path NO demo has run:
//     #76 smulorbit = G_SMULO at s16/s32 (__mulosi4);  #56 rotozoom = G_UMULH at s32;
//     #22 avalanche = __muldi3 (the LOW 64 bits only, never the high half).
//
// DIFFERENTIAL: integer-exact by construction. __builtin_mul_overflow is standard-defined:
//   *out = (T)(a*b) truncated to T; returns 1 iff the true (infinite-precision) product does not
//   fit in T. Host has native 64-bit; target lowers via the s64 mulh. The overflow FLAG depends on
//   the high 64 bits of the product, so a wrong high-half or a wrong signed sign-consistency check
//   diverges the CRC immediately.
//
// WIDTH DISCIPLINE: all integers uint16_t/int16_t/uint64_t/int64_t; no bare int; no float.
// See docs/plans/2026-07-02-101-snes-mulov64.md.

#ifndef MULOV64_H
#define MULOV64_H

#include <stdint.h>
#include <stdbool.h>

// CRC fold step (rotating XOR) — identical shape to the rest of the battery.
static inline uint16_t mo_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// --------------------------------------------------------------------------
// Differential gate: GATE_N steps of unsigned AND signed s64 mul-overflow.
// Operands grow with i so both non-overflow and overflow cases occur.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 121u
#endif

static uint16_t mulov64_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    uint16_t ov_count = (uint16_t)0u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        // Unsigned s64 multiply-overflow: operands ~2^31/2^30 growing -> product straddles 2^64.
        // G_UMULO s64 -> lowerMulo -> G_UMULH s64 (.lower(), threads the S32-mul-clamp).
        uint64_t ua = (uint64_t)0x80000000ULL + (uint64_t)i * (uint64_t)0x02000000ULL;
        uint64_t ub = (uint64_t)0x40000000ULL + (uint64_t)i * (uint64_t)0x04000000ULL;
        uint64_t up;
        bool uov = __builtin_mul_overflow(ua, ub, &up);

        // Signed s64 multiply-overflow: near +2^31 * growing -> product straddles INT64_MAX.
        // G_SMULO s64 -> lowerMulo -> G_SMULH s64 (.lower(), signed high-half sign-consistency).
        int64_t sa = (int64_t)0x70000000LL - (int64_t)i * (int64_t)0x00800000LL;
        int64_t sb = (int64_t)0x20000000LL + (int64_t)i * (int64_t)0x08000000LL;
        int64_t sp;
        bool sov = __builtin_mul_overflow(sa, sb, &sp);

        if (uov) ov_count++;
        if (sov) ov_count++;

        // Fold: low + high words of each truncated product, plus the running overflow count.
        // ov_count is the load-bearing mulh signal (it depends on the 128-bit high half).
        uint16_t v = (uint16_t)((uint16_t)(up & (uint64_t)0xFFFFu)
                              ^ (uint16_t)((up >> 48) & (uint64_t)0xFFFFu)
                              ^ (uint16_t)((uint64_t)sp & (uint64_t)0xFFFFu)
                              ^ (uint16_t)(((uint64_t)sp >> 32) & (uint64_t)0xFFFFu)
                              ^ (uint16_t)((uint16_t)ov_count * (uint16_t)3u));
        h = mo_fold(h, v);
    }
    return h;
}

// --------------------------------------------------------------------------
// Orbit state for the SNES ROM display.
// Each orbiter carries a 64-bit momentum scaled by a growing factor via s64 mul-overflow;
// overflow teleports it to the mirror quadrant and leaves a bright spark.
// --------------------------------------------------------------------------
typedef struct {
    uint8_t  px, py;   // position in [0..127]
    int8_t   vx, vy;   // velocity in [-8..8]
    uint8_t  spark;    // spark glow countdown
    uint64_t mom;      // 64-bit momentum (scaled until it overflows)
} MOrbiter;

#define MO_N 6           // number of orbiters
#define MO_SPARK_TTL 12  // frames a spark glows

static void mo_init(MOrbiter orbs[MO_N]) {
    for (uint8_t i = 0u; i < (uint8_t)MO_N; i++) {
        orbs[i].px    = (uint8_t)(8u + (uint8_t)(i * (uint8_t)20u));
        orbs[i].py    = (uint8_t)(16u + (uint8_t)(i * (uint8_t)15u));
        orbs[i].vx    = (int8_t)(1 + (int8_t)((int8_t)(i & 3)));
        orbs[i].vy    = (int8_t)(1 + (int8_t)((int8_t)((i >> 1) & 3)));
        orbs[i].spark = 0u;
        // Seed momentum near 2^40 so a few ×scale steps overflow s64.
        orbs[i].mom   = (uint64_t)0x0000010000000000ULL + (uint64_t)((uint64_t)i << 20);
    }
}

// Step one orbiter; return the colour to plot (1=dim, 2=medium, 3=spark).
static inline uint8_t mo_step(MOrbiter *o, uint16_t t) {
    // Growing scale factor (2..~34, wraps). mom * sf via unsigned s64 mul-overflow.
    uint64_t sf = (uint64_t)((uint64_t)((t >> 4) & (uint16_t)0x1Fu) + (uint64_t)2u);
    uint64_t prod;
    bool ov = __builtin_mul_overflow(o->mom, sf, &prod);

    if (ov) {
        // Overflow: teleport to mirror quadrant, reverse direction, reset momentum, spark.
        o->px    = (uint8_t)((uint8_t)127u - o->px);
        o->py    = (uint8_t)((uint8_t)127u - o->py);
        o->vx    = (int8_t)(-(int8_t)o->vx);
        o->vy    = (int8_t)(-(int8_t)o->vy);
        o->mom   = (uint64_t)0x0000010000000000ULL + (uint64_t)o->px;
        o->spark = (uint8_t)MO_SPARK_TTL;
        return (uint8_t)3u;
    }
    // Normal step: grow momentum, move by velocity.
    o->mom = prod | (uint64_t)1u;
    o->px  = (uint8_t)((uint8_t)((uint8_t)o->px + (uint8_t)o->vx) & (uint8_t)127u);
    o->py  = (uint8_t)((uint8_t)((uint8_t)o->py + (uint8_t)o->vy) & (uint8_t)127u);
    if (o->spark > (uint8_t)0u) o->spark--;
    return (o->spark > (uint8_t)0u) ? (uint8_t)2u : (uint8_t)1u;
}

#endif /* MULOV64_H */
