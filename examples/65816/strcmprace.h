// Lexicographic Race (#148) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster B. The corner: **`memcmp` / `strcmp` /
// `strncmp`** — three libc comparison functions used **zero** times tree-wide across demos
// #1-#141. `strlen` (1x) and `qsort` (15x) are the only string/search libc the battery
// touches; #66 editdist compares characters by hand and #46 qsortviz compares numbers, so
// none of the three symbols has ever been linked into a gated ROM.
//
// MEASURED NEGATIVE, recorded honestly: the ideas doc also predicted clang's **inline small-
// `memcmp` expansion** as a second, distinct lowering. It does not exist on this target —
// `memcmp(a,b,2)`, `memcmp(a,b,4) == 0` (the equality-only form other targets specialise) and
// `memcmp(a,b,8)` all emit `jsr memcmp`, because MOS does not override
// TargetTransformInfo::enableMemCmpExpansion. So this demo covers three never-linked libcalls
// and their three-way sign contract, NOT a second lowering, and its structure gate asserts
// only what is actually there.
//
// MECHANISM: fixed-width string lanes merged under a real lexicographic order.
//   * `strcmp`  drives the sort — NUL-terminated, unbounded.
//   * `strncmp` over a SHORT prefix bound, which returns 0 for pairs that share that prefix
//     while `strcmp` on the same pair does not — the contrast that makes the bound load-bearing.
//   * `memcmp`  over the FULL fixed width including the terminator and the deterministic
//     filler past it, so every byte of the record participates.
// The lane alphabet is built with deliberate shared prefixes so all three functions produce
// all three signs (negative, zero, positive) over the run; a lane set that only ever compared
// one way would leave two thirds of the contract untested.
//
// DIFFERENTIAL: the CRC folds the **SIGN** of every comparison, normalised to -1 / 0 / +1 —
// never the magnitude, which is explicitly implementation-defined (C17 7.24.4: the functions
// return "greater than, equal to, or less than zero", not a particular value). It also folds
// the byte position at which each comparison resolved, computed by this header's OWN scan
// rather than read out of the libc, and the final merged ordering.
// WIDTH DISCIPLINE: explicit uint8/16/32; lane bytes are unsigned char throughout, because
// the sign of a comparison on bytes above 0x7F depends on it.
// See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md.

#ifndef STRCMPRACE_H
#define STRCMPRACE_H

#include <stdint.h>
#include <string.h>   /* memcmp, strcmp, strncmp */

#define SR_N     24u   /* lanes                                       */
#define SR_W     12u   /* lane width in bytes, terminator included    */
#define SR_LEN   (SR_W - 1u)   /* max characters before the NUL       */
#define SR_PFX    3u   /* the strncmp bound — short, on purpose       */
#define SR_LOG  256u   /* recorded comparisons                        */

static char     sr_lane[SR_N][SR_W];
static uint8_t  sr_order[SR_N];        /* lane indices, sorted by strcmp          */
static int8_t   sr_sgn[SR_LOG];        /* normalised sign of each comparison      */
static uint8_t  sr_at[SR_LOG];         /* byte position where it resolved         */
static uint8_t  sr_fn[SR_LOG];         /* 0 = strcmp, 1 = strncmp, 2 = memcmp     */
static uint16_t sr_nlog;
static uint16_t sr_cnt[3][3];          /* [fn][sign+1] — the coverage cross-check */

static uint16_t sr_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

/* Normalise any of the three functions' return value to -1 / 0 / +1. This, not the raw
   return, is what the differential folds. */
static int8_t sr_sign(int r) {
    if (r < 0) return (int8_t)-1;
    if (r > 0) return (int8_t)1;
    return (int8_t)0;
}

/* Where a comparison resolved — our own instrument, not the libc's. Scans at most `n` bytes
   and returns the first differing position, or `n` if the two runs agree throughout. Unsigned
   char, because that is the comparison the three libc functions are specified to perform. */
static uint8_t sr_resolve_at(const char *a, const char *b, uint8_t n, uint8_t stop_at_nul) {
    for (uint8_t i = (uint8_t)0u; i < n; i++) {
        unsigned char ca = (unsigned char)a[i];
        unsigned char cb = (unsigned char)b[i];
        if (ca != cb) return i;
        if (stop_at_nul && ca == (unsigned char)0u) return i;
    }
    return n;
}

static void sr_log(uint8_t fn, int8_t sgn, uint8_t at) {
    if (sr_nlog < (uint16_t)SR_LOG) {
        sr_fn[sr_nlog]  = fn;
        sr_sgn[sr_nlog] = sgn;
        sr_at[sr_nlog]  = at;
        sr_nlog = (uint16_t)(sr_nlog + 1u);
    }
    sr_cnt[fn][(uint8_t)((int8_t)(sgn + (int8_t)1))] =
        (uint16_t)(sr_cnt[fn][(uint8_t)((int8_t)(sgn + (int8_t)1))] + 1u);
}

// The sort's comparison step: `strcmp`, unbounded and NUL-terminated. noinline so the libcall
// stays a real call under real register pressure instead of being hoisted into the loop.
__attribute__((noinline))
static int8_t sr_cmp_full(uint8_t i, uint8_t j) {
    int8_t s = sr_sign(strcmp(sr_lane[i], sr_lane[j]));
    sr_log((uint8_t)0u, s, sr_resolve_at(sr_lane[i], sr_lane[j], (uint8_t)SR_W, (uint8_t)1u));
    return s;
}

// The bounded form. With SR_PFX = 3 and lanes built to share prefixes, this returns 0 for
// many pairs whose strcmp does not — which is the whole reason the bound exists.
__attribute__((noinline))
static int8_t sr_cmp_pfx(uint8_t i, uint8_t j) {
    int8_t s = sr_sign(strncmp(sr_lane[i], sr_lane[j], (size_t)SR_PFX));
    sr_log((uint8_t)1u, s, sr_resolve_at(sr_lane[i], sr_lane[j], (uint8_t)SR_PFX, (uint8_t)1u));
    return s;
}

// The fixed-width form. Runs over the whole record INCLUDING the terminator and the filler
// past it, so it does not stop at the NUL the way the other two do.
__attribute__((noinline))
static int8_t sr_cmp_mem(uint8_t i, uint8_t j) {
    int8_t s = sr_sign(memcmp(sr_lane[i], sr_lane[j], (size_t)SR_W));
    sr_log((uint8_t)2u, s, sr_resolve_at(sr_lane[i], sr_lane[j], (uint8_t)SR_W, (uint8_t)0u));
    return s;
}

static void sr_reset(void) {
    /* Lanes over a 6-letter alphabet with DELIBERATE shared prefixes: every lane's first
       SR_PFX characters come from a small pool of prefixes, so strncmp(.,.,SR_PFX) hits its
       zero arm often while strcmp keeps going. Length varies, so the NUL lands at different
       offsets and the filler past it differs between lanes — which is what gives memcmp a
       different answer from strcmp on some pairs. */
    static const char alpha[7] = "ABCDEF";
    static const char pfx[6][3] = {
        { 'A','B','C' }, { 'A','B','D' }, { 'B','A','A' },
        { 'C','C','C' }, { 'A','B','C' }, { 'B','A','A' },
    };
    uint16_t s = (uint16_t)0x3E97u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)SR_N; i++) {
        uint8_t p = (uint8_t)(i % (uint8_t)6u);
        sr_lane[i][0] = pfx[p][0];
        sr_lane[i][1] = pfx[p][1];
        sr_lane[i][2] = pfx[p][2];
        s = (uint16_t)(sr_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        uint8_t len = (uint8_t)((uint8_t)SR_PFX + (uint8_t)((s >> 6) % (uint16_t)6u));
        for (uint8_t k = (uint8_t)SR_PFX; k < len; k++) {
            s = (uint16_t)(sr_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
            sr_lane[i][k] = alpha[(uint8_t)((s >> 7) % (uint16_t)6u)];
        }
        sr_lane[i][len] = (char)0;
        /* Deterministic filler past the terminator: invisible to strcmp/strncmp, visible to
           memcmp. This is what makes the three functions genuinely disagree. */
        for (uint8_t k = (uint8_t)(len + 1u); k < (uint8_t)SR_W; k++)
            sr_lane[i][k] = (char)(uint8_t)((uint8_t)0x10u + (uint8_t)(i ^ k));
        sr_order[i] = i;
    }
    /* One deliberate byte-for-byte DUPLICATE lane. Without it `memcmp` never returns 0 — the
       per-lane filler past each terminator is unique, so no two distinct lanes are equal over
       the full width — and the equality arm of the fixed-width comparison would go untested
       while `strcmp`'s and `strncmp`'s were exercised. (Measured: before this line,
       memcmp zero = 0 out of 46 comparisons.) */
    for (uint8_t k = (uint8_t)0u; k < (uint8_t)SR_W; k++)
        sr_lane[SR_N - 1u][k] = sr_lane[0][k];

    sr_nlog = (uint16_t)0u;
    for (uint8_t f = (uint8_t)0u; f < (uint8_t)3u; f++)
        for (uint8_t g = (uint8_t)0u; g < (uint8_t)3u; g++)
            sr_cnt[f][g] = (uint16_t)0u;
    for (uint16_t k = (uint16_t)0u; k < (uint16_t)SR_LOG; k++) {
        sr_sgn[k] = (int8_t)0; sr_at[k] = (uint8_t)0u; sr_fn[k] = (uint8_t)0u;
    }
}

// Insertion sort under strcmp — a stable, fully determined ordering over lanes that are not
// all distinct, so the merged result depends on the comparison signs and nothing else.
__attribute__((noinline))
static void sr_sort(void) {
    for (uint8_t i = (uint8_t)1u; i < (uint8_t)SR_N; i++) {
        uint8_t v = sr_order[i];
        uint8_t j = i;
        while (j > (uint8_t)0u && sr_cmp_full(sr_order[(uint8_t)(j - 1u)], v) > (int8_t)0) {
            sr_order[j] = sr_order[(uint8_t)(j - 1u)];
            j = (uint8_t)(j - 1u);
        }
        sr_order[j] = v;
    }
}

// The second pass: every adjacent pair of the sorted order compared again by the bounded and
// the fixed-width forms, so all three functions see the same pairs and their disagreements
// are directly observable.
__attribute__((noinline))
static void sr_race(void) {
    for (uint8_t i = (uint8_t)1u; i < (uint8_t)SR_N; i++) {
        (void)sr_cmp_pfx(sr_order[(uint8_t)(i - 1u)], sr_order[i]);
        (void)sr_cmp_mem(sr_order[(uint8_t)(i - 1u)], sr_order[i]);
        /* and the reversed pair, which is how the positive arm of each gets exercised */
        (void)sr_cmp_pfx(sr_order[i], sr_order[(uint8_t)(i - 1u)]);
        (void)sr_cmp_mem(sr_order[i], sr_order[(uint8_t)(i - 1u)]);
    }
    /* The duplicate pair, explicitly and in both directions. The adjacent-pair sweep above
       does NOT reach it reliably: the sort is by `strcmp`, several lanes share a string, and
       a stable sort can leave the two identical records non-adjacent — measured, memcmp's
       zero arm stayed at 0/46 until this was added. */
    (void)sr_cmp_full((uint8_t)0u, (uint8_t)(SR_N - 1u));
    (void)sr_cmp_pfx ((uint8_t)0u, (uint8_t)(SR_N - 1u));
    (void)sr_cmp_mem ((uint8_t)0u, (uint8_t)(SR_N - 1u));
    (void)sr_cmp_full((uint8_t)(SR_N - 1u), (uint8_t)0u);
    (void)sr_cmp_pfx ((uint8_t)(SR_N - 1u), (uint8_t)0u);
    (void)sr_cmp_mem ((uint8_t)(SR_N - 1u), (uint8_t)0u);
}

static uint16_t sr_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(sr_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: sort, race, fold signs + resolve positions + ordering.
// --------------------------------------------------------------------------
static uint16_t strcmprace_gate_crc(void) {
    uint16_t h = (uint16_t)0x6D14u;
    sr_reset();
    sr_sort();
    sr_race();

    for (uint8_t i = (uint8_t)0u; i < (uint8_t)SR_N; i++) {
        h = sr_mix(h, (uint16_t)sr_order[i]);
        for (uint8_t k = (uint8_t)0u; k < (uint8_t)SR_W; k++)
            h = sr_mix(h, (uint16_t)(uint8_t)sr_lane[i][k]);
    }
    h = sr_mix(h, sr_nlog);
    for (uint16_t k = (uint16_t)0u; k < sr_nlog; k++)
        h = sr_mix(h, (uint16_t)((uint16_t)(uint8_t)(sr_sgn[k] + (int8_t)1)
                                 | (uint16_t)((uint16_t)sr_at[k] << 2)
                                 | (uint16_t)((uint16_t)sr_fn[k] << 10)));
    for (uint8_t f = (uint8_t)0u; f < (uint8_t)3u; f++)
        for (uint8_t g = (uint8_t)0u; g < (uint8_t)3u; g++)
            h = sr_mix(h, sr_cnt[f][g]);
    return h;
}

/* The coverage cross-check the gate asserts: every one of the three functions must have
   produced every one of the three signs. Returns the number of (function, sign) cells that
   never fired — 0 means the three-way contract is fully exercised. */
static uint8_t sr_uncovered(void) {
    uint8_t n = (uint8_t)0u;
    for (uint8_t f = (uint8_t)0u; f < (uint8_t)3u; f++)
        for (uint8_t g = (uint8_t)0u; g < (uint8_t)3u; g++)
            if (sr_cnt[f][g] == (uint16_t)0u) n = (uint8_t)(n + 1u);
    return n;
}

#endif /* STRCMPRACE_H */
