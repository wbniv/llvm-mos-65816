// Shared, PURE bignum factorial math — host-linkable, no hardware.
//
// Computes n! incrementally as a base-10000 little-endian digit array using schoolbook
// carry-propagation multiply. Designed to stress:
//   __mulsi3      — (uint32_t)d[i] * (uint32_t)n in the inner carry loop
//   __udivmodsi4  — prod % FACT_BASE and prod / FACT_BASE (both quot+rem used → one call)
//   rep / sep     — native-16-bit accumulator array sweep under +mos-a16
//
// Width rules: no bare `int` (16-bit on SNES, 32-bit on host) — every value is explicitly
// sized. See docs/plans/2026-06-27-20-snes-bignum-factorial-factorial.md.
#ifndef FACTORIAL_H
#define FACTORIAL_H

#include <stdint.h>

// Base-10000: each element holds 4 decimal digits (0..9999).
// 1000! has ~2568 decimal digits → at most 642 elements. 700 gives margin.
#define FACT_BASE     10000u
#define FACT_MAXELEMS 700u
// Gate: compute 2! through FACT_GATE_N inclusive. 50! → ~32 elements.
// Completes well within the corpus-a16 SMOKE_SETTLE=60 frame window.
#define FACT_GATE_N   50u

typedef struct {
    uint16_t d[FACT_MAXELEMS];  // little-endian base-10000 (d[0] = least significant)
    uint16_t nelem;             // number of active elements
    uint16_t n;                 // last computed n (so d[] == n!)
} bignum_state;

// Initialise to 1! = 1.
static inline void bignum_init(bignum_state *s) {
    s->d[0] = 1u;
    s->nelem = 1u;
    s->n     = 1u;
}

// Multiply s (currently n!) by (n+1) in place: s becomes (n+1)!
// Hot loop: __mulsi3 + __udivmodsi4 per element.
__attribute__((noinline))
static void bignum_mul_n(bignum_state *s, uint16_t n) {
    uint32_t carry = 0u;
    uint16_t i;
    for (i = 0u; i < s->nelem; i++) {
        uint32_t prod = (uint32_t)s->d[i] * (uint32_t)n + carry;
        s->d[i] = (uint16_t)(prod % (uint32_t)FACT_BASE);
        carry   = prod / (uint32_t)FACT_BASE;
    }
    // Propagate any remaining carry into new high-order elements.
    while (carry && s->nelem < FACT_MAXELEMS) {
        s->d[s->nelem] = (uint16_t)(carry % (uint32_t)FACT_BASE);
        carry /= (uint32_t)FACT_BASE;
        s->nelem++;
    }
    s->n = n;
}

// Number of decimal digits in the current value (1 for zero).
static inline uint16_t bignum_ndigits(const bignum_state *s) {
    if (s->nelem == 0u) return 1u;
    // All elements below the top contribute exactly 4 digits.
    // The top element contributes 1-4 digits.
    uint16_t top = s->d[s->nelem - 1u];
    uint16_t top_digits = (top >= 1000u) ? 4u :
                          (top >=  100u) ? 3u :
                          (top >=   10u) ? 2u : 1u;
    return (uint16_t)((s->nelem - 1u) * 4u + top_digits);
}

// Decompose a uint16 into exactly 4 decimal character bytes at buf[0..3] (no NUL).
// buf[0] = most-significant decimal digit.
static inline void bignum_write4(char *buf, uint16_t v) {
    uint16_t a = (uint16_t)(v / 1000u);
    uint16_t b = (uint16_t)((v / 100u) % 10u);
    uint16_t c = (uint16_t)((v / 10u)  % 10u);
    uint16_t e = (uint16_t)(v % 10u);
    buf[0] = (char)('0' + a);
    buf[1] = (char)('0' + b);
    buf[2] = (char)('0' + c);
    buf[3] = (char)('0' + e);
}

// Decompose the most-significant element (up to 4 chars, no leading zeros).
// Returns the number of chars written (1..4). buf need not be NUL-terminated by caller.
static inline uint16_t bignum_write_msd(char *buf, uint16_t v) {
    if (v >= 1000u) { bignum_write4(buf, v); return 4u; }
    if (v >=  100u) {
        buf[0] = (char)('0' + v / 100u);
        buf[1] = (char)('0' + (v / 10u) % 10u);
        buf[2] = (char)('0' + v % 10u);
        return 3u;
    }
    if (v >=   10u) {
        buf[0] = (char)('0' + v / 10u);
        buf[1] = (char)('0' + v % 10u);
        return 2u;
    }
    buf[0] = (char)('0' + v);
    return 1u;
}

// Gate CRC: compute 2! through FACT_GATE_N, then XOR-rotate the digit array into a uint16.
// Pure function — creates its own local bignum_state.
static uint16_t factorial_gate_crc(void) {
    static bignum_state s;  // static: avoids 1.4 KB on the soft stack
    bignum_init(&s);
    uint16_t n;
    for (n = 2u; n <= (uint16_t)FACT_GATE_N; n++)
        bignum_mul_n(&s, n);
    // Fold digit array into a 16-bit hash.
    uint16_t h = s.nelem;
    uint16_t i;
    for (i = 0u; i < s.nelem; i++)
        h = (uint16_t)((h << 1) | (h >> 15)) ^ s.d[i];
    return h;
}

#endif /* FACTORIAL_H */
