// Shared, PURE GF(2^8) finite-field arithmetic (Reed-Solomon flavour) — host-linkable, no hardware.
// Demo #55.
//
// The codegen corner: an ALU profile with **NO carry chain at all** — GF(2^8) "carryless" multiply via
// log/antilog tables and XOR (gf_mul(a,b) = antilog[log[a] + log[b]]), plus the primitive-polynomial
// reduction loop (x <<= 1; if (x & 0x100) x ^= 0x11D). Addition in the field is a bare XOR; multiply is
// two table lookups + an add + a lookup. Nothing in the first 54 demos does field arithmetic — the
// nearest (CRC #40, TEA #30) still ride the ordinary integer carry paths.
//
// This is the arithmetic under Reed-Solomon / QR codes: the generator is α = 2 with primitive polynomial
// 0x11D (285), the QR/RS standard. The demo computes real RS **syndromes** (Horner evaluation of the
// received polynomial at α^j — zero for a clean codeword, non-zero when a symbol is corrupted).
//
// WIDTH DISCIPLINE: tables are uint8; the reduction accumulator is an explicit uint16 (the 9th bit test).
// All arithmetic is width-agnostic -> bit-exact host vs target.  See docs/plans/2026-06-30-55-snes-gf256.md.
#ifndef GF256_H
#define GF256_H

#include <stdint.h>

#define GF_POLY 0x11Du            // primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (QR/RS standard)

static uint8_t GF_LOG[256];
static uint8_t GF_EXP[512];       // doubled so log-sums up to 508 index directly (no % 255)
static uint8_t gf_ready = 0u;

// Build the log/antilog tables: EXP[i] = α^i, LOG[α^i] = i.  The α-power step is a shift with the
// primitive-polynomial reduction — the carryless-multiply core.
static void gf_init(void) {
    uint16_t x = 1u;
    for (uint16_t i = 0u; i < 255u; i++) {
        GF_EXP[i] = (uint8_t)x;
        GF_LOG[(uint8_t)x] = (uint8_t)i;
        x = (uint16_t)(x << 1);
        if (x & 0x100u) x ^= GF_POLY;      // reduce modulo the primitive polynomial (XOR, no carry)
    }
    for (uint16_t i = 255u; i < 510u; i++) GF_EXP[i] = GF_EXP[i - 255u];  // wrap for easy log-add
    GF_EXP[510] = GF_EXP[0]; GF_EXP[511] = GF_EXP[1];
    gf_ready = 1u;
}

// GF(2^8) multiply: log-add then antilog.  a==0 or b==0 -> 0.  The carryless product.
static inline uint8_t gf_mul(uint8_t a, uint8_t b) {
    if (a == 0u || b == 0u) return 0u;
    return GF_EXP[(uint16_t)GF_LOG[a] + (uint16_t)GF_LOG[b]];
}

// GF add/sub are the same XOR.
static inline uint8_t gf_add(uint8_t a, uint8_t b) { return (uint8_t)(a ^ b); }

// α^n (n mod 255), a table lookup.
static inline uint8_t gf_pow_alpha(uint8_t n) { return GF_EXP[n]; }

// Reed-Solomon syndrome S_j = R(α^j) = Σ_i R[i]·(α^j)^i, by Horner's rule in GF(2^8).  Zero iff R is a
// valid codeword.  This is the core RS error-detection operation and hammers gf_mul.
static uint8_t rs_syndrome(const uint8_t *r, uint8_t n, uint8_t j) {
    uint8_t aj = gf_pow_alpha(j);
    uint8_t s = 0u;
    for (uint8_t i = 0u; i < n; i++)
        s = (uint8_t)(gf_mul(s, aj) ^ r[i]);   // Horner: s = s·α^j + R[i]
    return s;
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t gf_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 200u
#endif

// Fold gf_mul over a spread of operand pairs, gf_pow, and RS syndromes of a walking message.  A
// miscompile in the table lookups, the log-add, the reduction, or the XOR chain diverges.  Also folds a
// slow bit-by-bit carryless multiply as an INDEPENDENT cross-check of gf_mul (they must agree).
static uint8_t gf_mul_slow(uint8_t a, uint8_t b) {   // reference carryless multiply, no tables
    uint8_t p = 0u;
    for (uint8_t k = 0u; k < 8u; k++) {
        if (b & 1u) p ^= a;
        uint8_t hi = (uint8_t)(a & 0x80u);
        a = (uint8_t)(a << 1);
        if (hi) a ^= (uint8_t)(GF_POLY & 0xFFu);
        b = (uint8_t)(b >> 1);
    }
    return p;
}

static uint16_t gf256_gate_crc(void) {
    if (!gf_ready) gf_init();
    uint16_t h = 0u;
    uint8_t msg[16];
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        uint8_t a = (uint8_t)((i << 2) ^ i ^ 1u);        // shift-spread operands, no multiply
        uint8_t b = (uint8_t)((i << 3) ^ (i << 1) ^ 3u);
        uint8_t m = gf_mul(a, b);
        h = gf_fold(h, (uint16_t)m);
        h = gf_fold(h, (uint16_t)gf_mul_slow(a, b));       // must equal m (independent cross-check)
        h = gf_fold(h, (uint16_t)gf_pow_alpha((uint8_t)(i & 0xFFu)));
        // build a 16-symbol message and fold two syndromes
        for (uint8_t k = 0u; k < 16u; k++)
            msg[k] = (uint8_t)(a ^ (uint8_t)((k << 4) ^ (uint8_t)(k << 1)) ^ b);   // shift-spread, no mul
        h = gf_fold(h, (uint16_t)rs_syndrome(msg, 16u, (uint8_t)(i & 7u)));
        h = gf_fold(h, (uint16_t)rs_syndrome(msg, 16u, (uint8_t)((i + 1u) & 7u)));
    }
    return h;
}

#endif /* GF256_H */
