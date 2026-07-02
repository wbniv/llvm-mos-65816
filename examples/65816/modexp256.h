// 256-bit Modular Exponentiation (#104) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster C (final). Re-stresses patch 0017's s64 (un)merge glue (#61
// dhmix) as a HIGH-VOLUME / HIGH-PRESSURE regression guard: dhmix's 64-bit Diffie-Hellman modexp at
// 256-bit. Honest framing (per the 2026-07-02 coverage-check note): there is NO s128/s256 node on a
// 16-bit target — a 256-bit number is built from uint32[8] limbs with uint64 multiply-accumulate, so
// this re-runs the *green* s64 path (uint64 mul/add/shift/compare = the (un)merge glue) hundreds of
// times under heavy register pressure. Its value is (a) a permanent regression guard for the glue and
// (b) stressing that glue × the regalloc/coalescer cluster — NOT forcing a new legalizer rule.
//
// Modulus m = 2^256 − 189 (pseudo-Mersenne → cheap fold reduction: 2^256 ≡ 189, so reduce a 512-bit
// product by folding the high half × 189 into the low half). PRIMALITY IS NOT NEEDED: the Diffie-
// Hellman identity A^b == B^a holds for ANY modulus because (g^a)^b = g^(ab) = (g^b)^a mod m — so a
// modmul miscompile (a dropped/duplicated limb from a wrong s64 lane split) breaks that equality AND
// diverges the CRC. DIFFERENTIAL: integer modexp is exact → bit-identical host vs target.
// WIDTH DISCIPLINE: uint32 limbs, uint64 accumulators; no float; no divide. See the plan.

#ifndef MODEXP256_H
#define MODEXP256_H

#include <stdint.h>

#define ME_LIMBS 8u          // 8 × 32-bit = 256-bit, little-endian
#define ME_C     ((uint32_t)189u)   // m = 2^256 − ME_C

typedef struct { uint32_t w[ME_LIMBS]; } U256;

static void me_zero(U256 *a) { for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) a->w[i] = 0u; }
static void me_set_u32(U256 *a, uint32_t v) { me_zero(a); a->w[0] = v; }

// Compare: return 1 if a >= b (unsigned 256-bit).
static uint8_t me_ge(const U256 *a, const U256 *b) {
    for (uint8_t i = (uint8_t)ME_LIMBS; i-- > 0u; ) {
        if (a->w[i] != b->w[i]) return (uint8_t)(a->w[i] > b->w[i]);
    }
    return 1u;   // equal
}

// out = a - b (assumes a >= b), 256-bit borrow chain.
static void me_sub(U256 *out, const U256 *a, const U256 *b) {
    uint64_t borrow = 0u;
    for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) {
        uint64_t cur = (uint64_t)a->w[i] - (uint64_t)b->w[i] - borrow;
        out->w[i] = (uint32_t)cur;
        borrow = (cur >> 63) & 1u;   // 1 if it underflowed
    }
}

// The modulus m = 2^256 − ME_C as a U256 (all-ones minus (C-1) in limb 0).
static void me_modulus(U256 *m) {
    for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) m->w[i] = 0xFFFFFFFFu;
    m->w[0] = (uint32_t)(0u - ME_C);   // 2^32 - C in limb 0; higher limbs all 0xFFFFFFFF → 2^256 - C
}

// r = (a * b) mod m, via schoolbook 256×256→512 (uint64 MAC) + pseudo-Mersenne fold reduction.
static void me_mulmod(U256 *r, const U256 *a, const U256 *b) {
    uint32_t p[2u * ME_LIMBS];   // 512-bit product, little-endian
    for (uint8_t i = 0u; i < (uint8_t)(2u * ME_LIMBS); i++) p[i] = 0u;

    // schoolbook multiply: each column accumulates uint64 MAC with a propagating uint64 carry.
    for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) {
        uint64_t carry = 0u;
        for (uint8_t j = 0u; j < (uint8_t)ME_LIMBS; j++) {
            uint64_t cur = (uint64_t)p[i + j] + (uint64_t)a->w[i] * (uint64_t)b->w[j] + carry;  // __muldi3 + adds
            p[i + j] = (uint32_t)cur;
            carry = cur >> 32;
        }
        uint8_t k = (uint8_t)(i + (uint8_t)ME_LIMBS);
        while (carry != 0u) {
            uint64_t cur = (uint64_t)p[k] + carry;
            p[k] = (uint32_t)cur;
            carry = cur >> 32;
            k++;
        }
    }

    // fold: value = pLow + 2^256 * pHigh ≡ pLow + ME_C * pHigh (mod m). Repeat until the high part is 0.
    // (Two folds suffice for small C, but loop to be safe.)
    uint32_t lo[ME_LIMBS], hi[ME_LIMBS];
    for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) { lo[i] = p[i]; hi[i] = p[i + ME_LIMBS]; }
    for (;;) {
        // t = ME_C * hi  (256-bit × 32-bit → up to 9 limbs); accumulate into lo, capture overflow.
        uint64_t carry = 0u;
        uint32_t t[ME_LIMBS];
        for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) {
            uint64_t cur = (uint64_t)ME_C * (uint64_t)hi[i] + carry;   // __muldi3-ish
            t[i] = (uint32_t)cur;
            carry = cur >> 32;
        }
        uint32_t t_top = (uint32_t)carry;   // limb 8 of ME_C*hi

        // lo += t (256-bit add), capture the carry beyond 256 bits.
        uint64_t add = 0u;
        for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) {
            uint64_t cur = (uint64_t)lo[i] + (uint64_t)t[i] + add;
            lo[i] = (uint32_t)cur;
            add = cur >> 32;
        }
        uint64_t overflow = add + (uint64_t)t_top;   // total carry out of bit 256
        if (overflow == 0u) break;
        // new hi = overflow (a small number < 2^33); loop to fold it in.
        for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) hi[i] = 0u;
        hi[0] = (uint32_t)overflow;
        hi[1] = (uint32_t)(overflow >> 32);
    }

    for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) r->w[i] = lo[i];
    // final canonicalization: at most a couple of conditional subtractions of m.
    U256 m;
    me_modulus(&m);
    while (me_ge(r, &m)) { U256 tmp; me_sub(&tmp, r, &m); *r = tmp; }
}

// r = base^exp mod m (square-and-multiply; exp is a small uint32 to bound the modmul count).
static void me_modexp(U256 *r, const U256 *base, uint32_t exp) {
    U256 result, b;
    me_set_u32(&result, 1u);
    b = *base;
    while (exp != 0u) {
        if ((exp & 1u) != 0u) { U256 t; me_mulmod(&t, &result, &b); result = t; }
        { U256 t; me_mulmod(&t, &b, &b); b = t; }
        exp >>= 1;
    }
    *r = result;
}

static inline uint16_t me_fold(uint16_t h, uint32_t x) {
    h = (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ (uint16_t)(x & 0xFFFFu));
    h = (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ (uint16_t)(x >> 16));
    return h;
}

// ---------------------------------------------------------------------------------------------
// Differential gate: GATE_N Diffie-Hellman exchanges at 256-bit. Each: A=g^a, B=g^b, then the shared
// secrets s1=B^a and s2=A^b — which MUST be equal. Fold s1 (and XOR in a mismatch witness s1^s2 so a
// broken modmul that makes s1 != s2 diverges the CRC hard).
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 1u          // 256-bit modexp is VERY heavy: 4 modexp × ~16 modmul/round. One DH
                            // exchange (64 × 256-bit modmuls) already saturates the s64 glue and
                            // settles corpus_result by ~frame 400 so MAME (frame 500) passes too.
#endif

static uint16_t modexp256_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        U256 g;
        me_set_u32(&g, (uint32_t)(5u + step));               // generator
        g.w[3] = (uint32_t)(0x9E3779B9u ^ (uint32_t)step);   // spread into a high limb (256-bit operands)
        g.w[6] = (uint32_t)(0x12345678u + (uint32_t)step);
        uint32_t a = (uint32_t)((step + 1u) * 0x00010007u) & 0xFFu;   // small secret exponents (8-bit)
        uint32_t b = (uint32_t)((step + 3u) * 0x00030005u) & 0xFFu;
        if (a == 0u) a = 7u;
        if (b == 0u) b = 11u;

        U256 A, B, s1, s2;
        me_modexp(&A, &g, a);      // g^a
        me_modexp(&B, &g, b);      // g^b
        me_modexp(&s1, &B, a);     // (g^b)^a
        me_modexp(&s2, &A, b);     // (g^a)^b  == s1 (DH)

        for (uint8_t i = 0u; i < (uint8_t)ME_LIMBS; i++) {
            h = me_fold(h, s1.w[i]);
            h = me_fold(h, (uint32_t)(s1.w[i] ^ s2.w[i]));   // mismatch witness: 0 when correct
        }
    }
    return h;
}

#endif /* MODEXP256_H */
