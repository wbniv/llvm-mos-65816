// 64-bit Multi-Key Record Sort (#100) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster B (final). Re-stresses patch 0016 (#46 qsortviz,
// `{G_SCMP,G_UCMP}.lower()` → LegalizerHelper::lowerThreewayCompare) at the EXTREME width with a
// CHAINED comparator: libc qsort of records keyed by a primary int64 spaceship, tie-broken by a
// SECOND int64 spaceship — so each comparator call emits **G_SCMP s64 twice**. #97 spaceship did
// one scmp per width; this stacks two s64 three-way compares per call with a data-dependent
// short-circuit between them (the tie-break only runs when the primary is equal).
//
// WHY qsort + why two keys tie: a direct `spaceship>0` folds back to `>` (the #97 lesson), so the
// scmp must flow through qsort's opaque callback. The primary key is drawn from a SMALL range so
// ties are frequent → the second s64 spaceship actually fires and is exercised, not dead code.
//
// DIFFERENTIAL: fold the sorted (k1,k2) pairs (NOT the tag). qsort is unstable, but records with
// identical (k1,k2) are interchangeable → the sorted (k1,k2) sequence is identical host vs target
// regardless of tie-break/pivot. A wrong s64 three-way lowering (primary OR tie-break) diverges the
// CRC. WIDTH DISCIPLINE: explicit int64; no bare int in data; no float.
// See docs/plans/2026-07-02-100-snes-keycmp64.md.

#ifndef KEYCMP64_H
#define KEYCMP64_H

#include <stdlib.h>
#include <stdint.h>

#define KC_N 24u   // records (qsort O(n log n); two s64 spaceships per compare = the slow leg)

typedef struct { int64_t k1, k2; uint16_t tag; } KCRec;

// Chained two-level comparator: primary int64 spaceship, then (on tie) a second int64 spaceship.
static int kc_cmp(const void *a, const void *b) {
    const KCRec *x = (const KCRec *)a, *y = (const KCRec *)b;
    int c = (int)((x->k1 > y->k1) - (x->k1 < y->k1));   // G_SCMP s64 (primary)
    if (c != 0) return c;
    return (int)((x->k2 > y->k2) - (x->k2 < y->k2));     // G_SCMP s64 (tie-break) — fires on k1 ties
}

// Fill: k1 from a SMALL signed range (frequent ties → the tie-break runs); k2 spans all 64 bits
// (so the second compare exercises every limb) and is signed both ways.
static void kc_fill(KCRec *r, uint16_t n, uint16_t seed) {
    uint16_t s = seed;
    for (uint16_t i = 0u; i < n; i++) {
        s = (uint16_t)(s * 25173u + 13849u); uint16_t a = s;
        s = (uint16_t)(s * 25173u + 13849u); uint16_t b = s;
        r[i].k1  = (int64_t)((int32_t)(a % 7u) - (int32_t)3);   // -3..3 → many ties
        r[i].k2  = (int64_t)(((uint64_t)a << 48) ^ ((uint64_t)b << 32)
                           ^ ((uint64_t)(uint16_t)(a ^ b) << 16) ^ (uint64_t)(uint16_t)(a + b));
        r[i].tag = i;
    }
}

static inline uint16_t kc_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: qsort records with the chained comparator, fold the sorted (k1,k2) pairs.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N KC_N
#endif

static KCRec _kc[KC_N];

static uint16_t keycmp64_gate_crc(void) {
    kc_fill(_kc, (uint16_t)KC_N, (uint16_t)0x7A5Cu);
    qsort(_kc, (size_t)KC_N, sizeof _kc[0], kc_cmp);
    uint16_t h = (uint16_t)0u;
    for (uint16_t i = 0u; i < (uint16_t)KC_N; i++) {
        uint64_t v1 = (uint64_t)_kc[i].k1, v2 = (uint64_t)_kc[i].k2;
        h = kc_fold(h, (uint16_t)(v1 ^ (v1 >> 16) ^ (v1 >> 32) ^ (v1 >> 48)));
        h = kc_fold(h, (uint16_t)(v2 ^ (v2 >> 16) ^ (v2 >> 32) ^ (v2 >> 48)));
    }
    return h;
}

// -------- ROM display: records as coloured rows, reordering under the two-level key -----------
#define KC_ROWS 16u

#endif /* KEYCMP64_H */
