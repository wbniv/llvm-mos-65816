// Shared, PURE multi-base odometer via libc div()/lldiv() — host-linkable, no hardware.  Demo #60.
//
// The codegen corner: the libc **div() / lldiv() returning div_t / lldiv_t BY VALUE** — the
// aggregate-return ABI braided with the custom G_SDIVREM legalizer (MOSLegalizerInfo.cpp:229,
// legalizeDivRem, which loads the remainder from a stack temporary).  Converting a number to base B is
// the natural div_t consumer: `div_t d = div(n, B); digit = d.rem; n = d.quot;` gets quotient and
// remainder in ONE call, returned as a two-field struct.  Distinct from #39 (constant `/`,`%` operators)
// and #43 (raw signed 64-bit divmod): here it is the *libc function* returning an *aggregate by value*.
//
// WIDTH DISCIPLINE (critical): div() takes `int` = 16-bit on target, 32-bit on host, so div() is only
// width-safe for values that fit a signed 16-bit int -> mb values are kept < 32768.  lldiv() takes
// `long long` = 64-bit on BOTH, so the 64-bit odometer is always safe.  (ldiv()'s `long` is 32/64 -> a
// mismatch, so it is deliberately NOT used.)  A noinline wrapper mb_div() forces the div_t by-value
// return even if div() itself would inline.  See docs/plans/2026-06-30-60-snes-multibase.md.
#ifndef MULTIBASE_H
#define MULTIBASE_H

#include <stdint.h>
#include <stdlib.h>          // div_t / div / lldiv_t / lldiv

// Force the div_t by-value return (the aggregate-return ABI) regardless of div() inlining.
__attribute__((noinline)) static div_t mb_div(int a, int b) { return div(a, b); }

// Convert v (< 32768, fits signed 16-bit int) to `base`, LSD first, up to ndig digits.  Uses div_t.
static uint8_t mb_to_base(uint16_t v, uint8_t base, uint8_t *digits, uint8_t ndig) {
    uint8_t n = 0u;
    int x = (int)v;
    for (uint8_t i = 0u; i < ndig; i++) {
        div_t d = mb_div(x, (int)base);        // quotient + remainder in one div_t (by value)
        digits[i] = (uint8_t)d.rem;
        x = d.quot;
        n = (uint8_t)(i + 1u);
        if (x == 0) break;
    }
    for (uint8_t i = n; i < ndig; i++) digits[i] = 0u;
    return n;
}

// 64-bit odometer digit extraction via lldiv (long long is 64-bit on host AND target -> always safe).
static uint8_t mb_to_base64(uint64_t v, uint8_t base, uint8_t *digits, uint8_t ndig) {
    uint8_t n = 0u;
    long long x = (long long)v;                // v kept < 2^63 by the caller
    for (uint8_t i = 0u; i < ndig; i++) {
        lldiv_t d = lldiv(x, (long long)base); // quotient + remainder as an lldiv_t (by value)
        digits[i] = (uint8_t)d.rem;
        x = d.quot;
        n = (uint8_t)(i + 1u);
        if (x == 0) break;
    }
    for (uint8_t i = n; i < ndig; i++) digits[i] = 0u;
    return n;
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t mb_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 60u          // 64-bit lldiv is heavy; keep the gate < ~450 frames (before the 500 checks)
#endif

// Fold base conversions (via div_t) of a sweep of values in bases 10/12/16/60, plus a 64-bit odometer
// (via lldiv_t).  A miscompile in the div_t/lldiv_t struct-return ABI or the G_SDIVREM legalizer
// (wrong quotient or remainder) diverges.  Also folds a reconstruction check (digits back to value).
static const uint8_t MB_BASES[4] = { 10u, 12u, 16u, 60u };

static uint16_t multibase_gate_crc(void) {
    uint16_t h = 0u;
    uint64_t odo = 1u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        uint16_t v = (uint16_t)((i * 271u + 13u) & 0x7FFFu);   // < 32768 (16-bit div_t safe)
        for (uint8_t b = 0u; b < 4u; b++) {
            uint8_t digs[6];
            uint8_t nd = mb_to_base(v, MB_BASES[b], digs, 6u);
            uint32_t recon = 0u, place = 1u;                   // 32-bit (same on host+target) -> no 16-bit overflow UB
            for (uint8_t k = 0u; k < nd; k++) {                // reconstruct to catch a wrong digit
                recon = recon + (uint32_t)digs[k] * place;
                place = place * (uint32_t)MB_BASES[b];
                h = mb_fold(h, (uint16_t)digs[k]);
            }
            h = mb_fold(h, (uint16_t)recon);                   // must equal v
        }
        // 64-bit odometer digits via lldiv (throttled — lldiv is heavy); keep odo < 10^18 (< 2^63)
        odo = odo * 3u + 7u;
        if (odo >= 1000000000000000000ULL) odo = 1u;
        if ((i & 3u) == 0u) {                              // every 4th iter
            uint8_t od[12];
            uint8_t on = mb_to_base64(odo, 10u, od, 12u);
            for (uint8_t k = 0u; k < on; k++) h = mb_fold(h, (uint16_t)od[k]);
        }
    }
    return h;
}

#endif /* MULTIBASE_H */
