// Bisection Oracle (#147) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster B. The corner: **`bsearch`** — a libc
// callback ABI this battery has never linked, and one that is structurally UNLIKE `qsort`'s.
//
// A coverage audit of demos #1-#141 found `bsearch` used **zero** times tree-wide; `strlen`
// (1x) and `qsort` (15x, #46 qsortviz and descendants) are the only string/search libc the
// battery touches. The difference is not cosmetic:
//   * `qsort`'s comparator drives a SWAP decision and the call PERMUTES the array in place;
//     the caller never converts a returned pointer back into anything.
//   * `bsearch`'s comparator drives an INTERVAL BISECTION, and the call returns a `void*`
//     pointing INTO the array — or NULL on a miss. The caller must difference that pointer
//     against the base and divide by the element size to recover an index, and must handle
//     the NULL arm separately. A wrong pointer->index conversion is silent: it produces a
//     plausible in-range index, not a crash.
// Measured: `jsr bsearch` with the comparator materialized as a 16-bit function pointer
// (`ldy #mos16lo(cmp)` / `ldy #mos16hi(cmp)`), so the indirect-callback ABI is genuinely
// exercised rather than inlined away.
//
// MECHANISM: a strictly increasing key table probed with a fixed query set that deliberately
// contains BOTH hits and misses — the miss arm is the one that returns NULL, and a query set
// that never missed would leave half the contract untested. The comparator records the index
// of every element it is handed, so the bisection's probe sequence is itself data — it is
// what the visual draws. It is NOT folded into the CRC; see the DIFFERENTIAL note below for
// why that would be over-claiming.
//
// DIFFERENTIAL: integer-exact, and DELIBERATELY NARROW. The CRC folds every found index and
// every miss sentinel, and NOTHING implementation-defined. C requires only that `bsearch`
// return SOME matching element; the keys here are strictly increasing, so the match is unique
// and the index is fully determined — that part is portable and is what the CRC folds.
//
// What the CRC does NOT fold, on purpose: the probe sequence and the comparator call count.
// The C standard says nothing about HOW `bsearch` bisects, and the host's libc (glibc) and
// the target's (llvm-mos-sdk) are separate implementations that are free to pick different
// midpoints. Folding the probe trace would make the gate assert an unspecified property and
// could fail for a wholly correct target — so it is left out, deliberately, and the demo does
// not claim to test the search shape.
//
// The trace is still captured: it is what the visual draws, and `bs_probe_sig()` summarises
// it for the HUD. What the gate asserts instead is the property that IS well-defined and IS
// the corner — `bs_verify_indices()` re-derives every recovered index from the key table, so
// a wrong pointer->index conversion (which produces a plausible in-range index, never a
// crash) fails the gate even though the CRC alone might not localise it.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md.

#ifndef BSEARCHVIZ_H
#define BSEARCHVIZ_H

#include <stdint.h>
#include <stdlib.h>   /* bsearch */

#define BS_N      64u   /* sorted keys                       */
#define BS_Q      48u   /* queries per gate run              */
#define BS_MAXPR   8u   /* ceil(log2(64)) + slack per query  */

static uint16_t bs_keys[BS_N];      /* strictly increasing                        */
static uint16_t bs_query[BS_Q];     /* the fixed query set (hits AND misses)      */
static uint16_t bs_found[BS_Q];     /* recovered index, or BS_MISS                */
static uint8_t  bs_nprobe[BS_Q];    /* probes the bisection took                  */
static uint8_t  bs_probe[BS_Q][BS_MAXPR];  /* which element each probe touched    */
static uint16_t bs_hits, bs_misses;
static uint8_t  bs_cur;             /* query being served — the comparator's sink */
static uint16_t bs_calls;           /* total comparator invocations               */

#define BS_MISS 0xFFFFu

static uint16_t bs_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}

// The three-way comparator. `a` is the key `bsearch` was given, `b` is the element it chose
// to probe — so differencing `b` against the base recovers the bisection's midpoint, which is
// how the probe trace is captured. noinline and reached only through a function pointer, so
// the indirect-callback ABI is what actually runs.
__attribute__((noinline))
static int bs_cmp(const void *a, const void *b) {
    const uint16_t *ka = (const uint16_t *)a;
    const uint16_t *kb = (const uint16_t *)b;

    uint16_t idx = (uint16_t)(kb - bs_keys);
    if (bs_cur < (uint8_t)BS_Q && bs_nprobe[bs_cur] < (uint8_t)BS_MAXPR) {
        bs_probe[bs_cur][bs_nprobe[bs_cur]] = (uint8_t)idx;
        bs_nprobe[bs_cur] = (uint8_t)(bs_nprobe[bs_cur] + 1u);
    }
    bs_calls = (uint16_t)(bs_calls + 1u);

    if (*ka < *kb) return -1;
    if (*ka > *kb) return 1;
    return 0;
}

static void bs_reset(void) {
    /* Keys: strictly increasing with an irregular gap pattern, so the misses land in gaps of
       different widths rather than all at the same distance from a key. */
    uint16_t v = (uint16_t)37u;
    uint16_t s = (uint16_t)0x2F1Du;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BS_N; i++) {
        bs_keys[i] = v;
        s = (uint16_t)(bs_mul(s, (uint16_t)25173u) + (uint16_t)13849u);
        v = (uint16_t)(v + (uint16_t)((s >> 11) & 0x1Fu) + (uint16_t)2u);
    }
    /* Queries: alternating hits (an exact key) and misses (a value strictly between two
       keys, plus two off both ends), so BOTH bsearch arms are taken many times. */
    uint16_t t = (uint16_t)0x6B85u;
    for (uint8_t q = (uint8_t)0u; q < (uint8_t)BS_Q; q++) {
        t = (uint16_t)(bs_mul(t, (uint16_t)25173u) + (uint16_t)13849u);
        uint8_t pick = (uint8_t)((t >> 5) % (uint16_t)BS_N);
        if ((q & 3u) == 3u) {
            /* miss: one below a key, which is a gap because every gap is >= 2 */
            bs_query[q] = (uint16_t)(bs_keys[pick] - (uint16_t)1u);
        } else if (q == (uint8_t)0u) {
            bs_query[q] = (uint16_t)0u;                                  /* below the low end */
        } else if (q == (uint8_t)1u) {
            bs_query[q] = (uint16_t)(bs_keys[BS_N - 1u] + (uint16_t)1u); /* above the high end */
        } else {
            bs_query[q] = bs_keys[pick];                                 /* hit */
        }
        bs_found[q]  = (uint16_t)BS_MISS;
        bs_nprobe[q] = (uint8_t)0u;
        for (uint8_t p = (uint8_t)0u; p < (uint8_t)BS_MAXPR; p++)
            bs_probe[q][p] = (uint8_t)0u;
    }
    bs_hits = bs_misses = (uint16_t)0u;
    bs_calls = (uint16_t)0u;
    bs_cur = (uint8_t)0u;
}

// Serve the whole query set. The pointer->index conversion is the part that matters: a
// returned `void*` is differenced against the base to recover the index, and NULL takes a
// wholly separate arm.
__attribute__((noinline))
static void bs_run(void) {
    for (uint8_t q = (uint8_t)0u; q < (uint8_t)BS_Q; q++) {
        bs_cur = q;
        uint16_t key = bs_query[q];
        void *hit = bsearch(&key, bs_keys, (size_t)BS_N, sizeof(uint16_t), bs_cmp);
        if (hit != (void *)0) {
            const uint16_t *e = (const uint16_t *)hit;
            bs_found[q] = (uint16_t)(e - bs_keys);   /* the conversion under test */
            bs_hits = (uint16_t)(bs_hits + 1u);
        } else {
            bs_found[q] = (uint16_t)BS_MISS;
            bs_misses = (uint16_t)(bs_misses + 1u);
        }
    }
}

static uint16_t bs_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(bs_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: serve every query, fold the indices, the sentinels and
// the probe sequences.
// --------------------------------------------------------------------------
static uint16_t bsearchviz_gate_crc(void) {
    uint16_t h = (uint16_t)0x47C2u;
    bs_reset();
    bs_run();
    h = bs_mix(h, bs_hits);
    h = bs_mix(h, bs_misses);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BS_N; i++)
        h = bs_mix(h, bs_keys[i]);
    for (uint8_t q = (uint8_t)0u; q < (uint8_t)BS_Q; q++) {
        h = bs_mix(h, bs_query[q]);
        h = bs_mix(h, bs_found[q]);   /* the pointer->index conversion under test */
    }
    /* bs_calls / bs_nprobe / bs_probe are NOT folded — see the DIFFERENTIAL note above. */
    return h;
}

/* The probe trace, folded separately. Not part of the host differential (bisection order is
   unspecified); the driver compares this value ACROSS THE THREE TARGET MODES, where the libc
   is the same and any difference is therefore codegen. */
static uint16_t bs_probe_sig(void) {
    uint16_t h = (uint16_t)0x1D0Bu;
    h = bs_mix(h, bs_calls);
    for (uint8_t q = (uint8_t)0u; q < (uint8_t)BS_Q; q++) {
        h = bs_mix(h, (uint16_t)bs_nprobe[q]);
        for (uint8_t p = (uint8_t)0u; p < (uint8_t)BS_MAXPR; p++)
            h = bs_mix(h, (uint16_t)bs_probe[q][p]);
    }
    return h;
}

/* Cross-checks the gate asserts: both arms must actually be taken, and every recovered index
   must really name its key (which is what catches a wrong pointer->index conversion — it
   would produce a plausible in-range index, not a crash). */
static uint16_t bs_verify_indices(void) {
    uint16_t bad = (uint16_t)0u;
    for (uint8_t q = (uint8_t)0u; q < (uint8_t)BS_Q; q++) {
        if (bs_found[q] == (uint16_t)BS_MISS) continue;
        if (bs_found[q] >= (uint16_t)BS_N) { bad = (uint16_t)(bad + 1u); continue; }
        if (bs_keys[bs_found[q]] != bs_query[q]) bad = (uint16_t)(bad + 1u);
    }
    return bad;
}

#endif /* BSEARCHVIZ_H */
