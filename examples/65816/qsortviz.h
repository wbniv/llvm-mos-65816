// Shared, PURE libc-qsort + comparator-callback sort — host-linkable.  Demo #46.
//
// The codegen corner: **libc `qsort` with a function-pointer comparator** — an INDIRECT call back into
// C per comparison, through a `int (*)(const void*, const void*)` pointer that qsort receives and
// invokes.  Distinct from the battery's hand-written sorts (#17): here the sort is library code that
// calls BACK into our comparator, so the whole indirect-comparator ABI (arg marshalling of two
// `const void*`, an `int` return, the call through a runtime-supplied pointer) is exercised.
//
// Differential safety: the gate folds the sorted VALUES, not original identities — so even if the host
// and target qsort break ties between EQUAL elements differently, the sorted sequence of values is
// identical (every comparator below leaves a tie only between equal values).  Width: int16_t values,
// comparators return int in {-1,0,1}; the fold masks to uint16_t.
// See docs/plans/2026-06-30-46-snes-qsortviz.md.
#ifndef QSORTVIZ_H
#define QSORTVIZ_H

#include <stdlib.h>
#include <stdint.h>

#define QS_N 64u

// --- comparators (each is a callback qsort invokes indirectly) ---

static int qs_cmp_asc(const void *a, const void *b) {
    int16_t x = *(const int16_t *)a, y = *(const int16_t *)b;
    return (int)((x > y) - (x < y));                 // ascending by value
}
static int qs_cmp_desc(const void *a, const void *b) {
    int16_t x = *(const int16_t *)a, y = *(const int16_t *)b;
    return (int)((y > x) - (y < x));                 // descending by value
}
static int qs_cmp_parity(const void *a, const void *b) {
    int16_t x = *(const int16_t *)a, y = *(const int16_t *)b;
    int px = (int)(x & 1), py = (int)(y & 1);
    if (px != py) return px - py;                     // evens first, then odds
    return (int)((x > y) - (x < y));                  // ...then ascending
}

typedef int (*qs_cmp_fn)(const void *, const void *);

// Deterministic LCG fill (so host and target start from the identical array).
static void qs_fill(int16_t *a, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0; i < n; i++) {
        s = (uint16_t)(s * 25173u + 13849u);
        a[i] = (int16_t)(s % 1000u);
    }
}

// ---------------------------------------------------------------------------------------------
// Differential gate: qsort the array under three comparators, folding the sorted values each pass.

static inline uint16_t qs_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

static uint16_t qsortviz_gate_crc(void) {
    static int16_t a[QS_N];
    static const qs_cmp_fn cmps[3] = { qs_cmp_asc, qs_cmp_parity, qs_cmp_desc };
    uint16_t h = 0;
    for (uint8_t pass = 0; pass < 3; pass++) {
        qs_fill(a, QS_N, (uint16_t)(0xC0DEu + pass));
        qsort(a, QS_N, sizeof a[0], cmps[pass]);       // library calls BACK into our comparator
        for (uint16_t i = 0; i < QS_N; i++)
            h = qs_fold(h, (uint16_t)a[i]);
    }
    return h;
}

#endif /* QSORTVIZ_H */
