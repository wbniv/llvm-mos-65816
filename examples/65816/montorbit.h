// Montgomery Orbit (#84) — shared, portable logic header.
//
// Stresses: Montgomery modular multiplication (REDC) — a*b mod N using only
//   __mulsi3 (32-bit product), G_LSHR (>>16 high-word extract), G_AND (mask mod R),
//   __mulhi3 (16-bit mul), and a conditional subtract. NO __udivsi3/__umodsi3.
// This is the DIVISION-FREE modmul member of the battery. Distinct from:
//   #61 dhmix: 64-bit modexp via __udivdi3/__umoddi3 (division-based)
//   #20 factorial / #19 pi: base-10000 bignum via __udivmodsi4 (division-based)
//
// The orbit x_i = g^i mod N (repeated mont_mul by g) traces a star polygon.
//
// WIDTH DISCIPLINE: int16_t/uint16_t + explicit (uint32_t) for products. No bare int.
// DIFFERENTIAL: Montgomery REDC is exact integer arithmetic — bit-identical host vs
// 65816. Any wrong 32-bit product, shift, mask, or the conditional-subtract branch
// diverges the orbit fold immediately.
//
// See docs/plans/2026-07-01-84-snes-montorbit.md.

#ifndef MONTORBIT_H
#define MONTORBIT_H

#include <stdint.h>

// Modulus (16-bit odd prime), R = 2^16, N' = -N^{-1} mod 2^16.
// N = 40961 (0xA001), prime. N' computed offline: N*N' ≡ -1 (mod 2^16).
#define MO_N      ((uint16_t)40961u)
#define MO_NPRIME ((uint16_t)40959u)   // -N^{-1} mod 2^16  (verify: (N*NPRIME)&0xFFFF == 0xFFFF)
#define MO_G      ((uint16_t)3u)        // generator of the orbit
#ifndef MO_K
#define MO_K      64u                   // orbit points
#endif
#ifndef MO_GATE_N
#define MO_GATE_N MO_K
#endif

// Montgomery reduction of a 32-bit product T (with a,b < N so T < N^2 < 2^32).
// REDC(T) = (T + ((T & 0xFFFF)*N' & 0xFFFF)*N) >> 16, then conditional subtract N.
static inline uint16_t mo_redc(uint32_t T) {
    uint16_t m = (uint16_t)((uint16_t)((uint16_t)T & 0xFFFFu) * MO_NPRIME); // __mulhi3 + G_AND
    uint32_t t = (uint32_t)((T + (uint32_t)((uint32_t)m * (uint32_t)MO_N)) >> 16); // __mulsi3, G_LSHR
    uint16_t r = (uint16_t)t;
    if (r >= MO_N) r = (uint16_t)(r - MO_N);   // conditional subtract
    return r;
}

// Montgomery product of two residues in [0, N).
static inline uint16_t mo_mul(uint16_t a, uint16_t b) {
    return mo_redc((uint32_t)((uint32_t)a * (uint32_t)b));   // __mulsi3
}

// Convert an ordinary integer to Montgomery form: aR mod N = mo_mul(a, R^2 mod N).
// R^2 mod N precomputed. For N=40961, R=2^16: R mod N = 65536-40961 = 24575;
// R^2 mod N computed at runtime once (division-free is not required for the one-time setup,
// but we compute it with mo_mul to stay division-free): use the identity to_mont(1)=R mod N.
#define MO_R_MOD_N ((uint16_t)24575u)      // 2^16 mod N (verified)
#define MO_R2_MOD_N ((uint16_t)1641u)      // 2^32 mod N (verified: (R mod N)^2 mod N)

static inline uint16_t mo_to_mont(uint16_t a) {
    return mo_mul(a, MO_R2_MOD_N);         // aR mod N
}

// ------------------------------------------------------------------
// Gate CRC: walk the orbit x_i = g^i (Montgomery form), fold each residue's
// canonical (out-of-Montgomery) value with prime multipliers.
// ------------------------------------------------------------------
static uint16_t montorbit_gate_crc(void) {
    uint16_t g_mont = mo_to_mont(MO_G);       // g in Montgomery form
    uint16_t x_mont = mo_to_mont((uint16_t)1u); // start at g^0 = 1 (Montgomery)
    uint16_t h = 0u;
    uint16_t i;
    for (i = 0u; i < (uint16_t)MO_GATE_N; i++) {
        // Canonical value = REDC(x_mont) = x_mont * 1 out of Montgomery form.
        uint16_t canon = mo_redc((uint32_t)x_mont);
        h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
        h = (uint16_t)(h ^ (uint16_t)((int16_t)canon * (int16_t)97) ^ (uint16_t)((uint16_t)i * 13u));
        x_mont = mo_mul(x_mont, g_mont);      // advance the orbit
    }
    return h;
}

// Orbit point i as a canonical residue (for the ROM's polyline).
static inline uint16_t mo_orbit_point(uint16_t g_mont, uint16_t *x_mont) {
    uint16_t canon = mo_redc((uint32_t)(*x_mont));
    *x_mont = mo_mul(*x_mont, g_mont);
    return canon;
}

#endif /* MONTORBIT_H */
