// Shared, PURE Diffie-Hellman colour-mixer via 64-bit modular exponentiation — host-linkable.  Demo #61.
//
// The codegen corner: **64-bit modulo (`__umoddi3`) as the HOT op** inside a square-and-multiply modular
// exponentiation.  modpow(base, exp, mod) does, per bit of exp, up to two `result = result*base % mod`
// and one `base = base*base % mod` — each a 64-bit multiply (__muldi3) followed by a 64-bit remainder
// (__umoddi3).  Distinct from #22 (avalanche: 64-bit mul/shift/xor, no modulo) and #27 (cardioid: 16/32-
// bit `%`).  A 64-bit `%`-per-iteration loop is neither.
//
// The demo is Diffie-Hellman: two parties pick secrets a, b; publish A = g^a mod p and B = g^b mod p;
// then both compute the shared secret s = B^a mod p == A^b mod p == g^(a·b) mod p.  Colours derived from
// A and B "mix" to the SAME shared colour — the visual proof that both sides converge.
//
// WIDTH / OVERFLOW SAFETY: all values are uint64 (identical host & target).  The modulus p is kept
// < 2^32, so every operand is < 2^32 and each product result*base < 2^64 (no uint64 overflow before the
// `% mod`).  uint64 arithmetic is bit-exact host vs target.  See docs/plans/2026-06-30-61-snes-dhmix.md.
#ifndef DHMIX_H
#define DHMIX_H

#include <stdint.h>

#define DH_P 4294967291ULL   // largest prime < 2^32 (2^32 - 5); operands < 2^32 -> products < 2^64
#define DH_G 5ULL            // a generator mod p

// Modular exponentiation by square-and-multiply.  Hot ops: 64-bit multiply (__muldi3) + 64-bit modulo
// (__umoddi3) per exponent bit.
static uint64_t dh_modpow(uint64_t base, uint64_t exp, uint64_t mod) {
    uint64_t result = 1u;
    base = base % mod;                       // __umoddi3
    while (exp != 0u) {
        if (exp & 1u) result = (result * base) % mod;   // __muldi3 + __umoddi3 (< 2^64, then reduce)
        base = (base * base) % mod;                      // __muldi3 + __umoddi3
        exp >>= 1;                                        // __lshrdi3
    }
    return result;
}

// Map a 64-bit field element to a small colour index (0..ncol-1).
static inline uint8_t dh_color(uint64_t v, uint8_t ncol) {
    return (uint8_t)((uint32_t)(v ^ (v >> 20) ^ (v >> 40)) % ncol);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t dh_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 8u            // 64-bit modexp is very heavy (~4 modpow x ~20 modmuls/iter); keep the
#endif                       // gate small so corpus_result is set before the 500-frame checks

// Fold Diffie-Hellman rounds: for each (a,b), A=g^a, B=g^b, and the two shared-secret computations
// B^a and A^b — which MUST be equal (the DH property).  Folding both catches a modpow miscompile; the
// equality is an independent cross-check baked into the fold (a divergence flips the hash).
static uint16_t dhmix_gate_crc(void) {
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        uint64_t a = (uint64_t)(((uint32_t)i * 2654435761u + 12345u) & 0xFFFFFu);  // secret exps (< 2^20)
        uint64_t b = (uint64_t)(((uint32_t)i * 40503u + 777u) & 0xFFFFFu);
        uint64_t A = dh_modpow(DH_G, a, DH_P);
        uint64_t B = dh_modpow(DH_G, b, DH_P);
        uint64_t s1 = dh_modpow(B, a, DH_P);    // shared = B^a
        uint64_t s2 = dh_modpow(A, b, DH_P);    // shared = A^b  (== s1)
        h = dh_fold(h, (uint16_t)A);
        h = dh_fold(h, (uint16_t)(A >> 16));
        h = dh_fold(h, (uint16_t)B);
        h = dh_fold(h, (uint16_t)s1);
        h = dh_fold(h, (uint16_t)(s1 >> 16));
        h = dh_fold(h, (uint16_t)(s1 ^ s2));    // 0 if the DH property holds (both sides agree)
    }
    return h;
}

#endif /* DHMIX_H */
