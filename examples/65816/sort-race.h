// Shared, PURE sorting-race math — host-linkable, no hardware.
//
// Three classic comparison sorts run on the SAME shuffled permutation of 0..SR_N-1:
//   * sr_qsort — recursive Hoare quicksort  (genuine recursion — soft-stack / frame-ABI stress)
//   * sr_hsort — iterative heapsort          (the non-recursive contrast)
//   * sr_msort — recursive top-down mergesort (genuine recursion; out-of-place via a temp buffer)
//
// Codegen stress (#17 of the compiler stress-test battery): recursion forces the backend's
// reentrant soft-stack spill path — a pointer into the caller's array lives across a self-jsr
// (the exact machinery examples/65816/a16spillr.c guards in isolation) — plus compare-heavy inner
// loops (lots of `cmp`) and `rep`/`sep` from native-16 array indexing under +mos-a16. NO 32-bit
// libcalls: this demo is about control flow, not wide arithmetic.
//
// Each sort takes a SortTrace*: it always counts comparisons (t->cmps) and element-stores
// (t->moves), and — when t->ops != NULL — appends each store as a packed (pos<<8)|value op so the
// SNES renderer can replay the sort one step per frame. The differential gate passes ops=NULL
// (counts only); the renderer passes a buffer. Same source on host (int=32) and 65816 (int=16):
// every value is uint16_t/uint8_t/int16_t, every shift casts back, so both must agree bit-for-bit.
//
// No hardware here (no snes.h, no MMIO). See docs/plans/2026-06-28-17-snes-sort-race.md.
#ifndef SORT_RACE_H
#define SORT_RACE_H

#include <stdint.h>

// Bars per algorithm. 32 = one 8px tile column each across the 256px screen; recursion depth
// stays tiny vs the ~5KB soft stack (mergesort O(log N); quicksort mid-pivot on N=32).
#ifndef SR_N
#define SR_N 32u
#endif

// Differential-gate rounds: each reshuffles and sorts three ways, exercising the recursion
// repeatedly. 8 rounds keeps the gate well under ~120 frames of SNES compute.
#define SR_GATE_ROUNDS 8u

// ---------------------------------------------------------------------------------------------
// Trace: comparison/move counters + optional op-log for the renderer.

typedef struct {
    uint16_t  cmps;   // comparisons performed
    uint16_t  moves;  // element-stores performed (== ops appended when recording)
    uint16_t *ops;    // NULL = count only; else packed (pos<<8)|value, one per store
    uint16_t  nops;   // ops appended so far
    uint16_t  cap;    // capacity of ops[] (appends past cap are dropped)
} SortTrace;

static inline void sr_trace_init(SortTrace *t, uint16_t *ops, uint16_t cap) {
    t->cmps = 0; t->moves = 0; t->ops = ops; t->nops = 0; t->cap = cap;
}

// Record "a[pos] became val": bump the move counter, append an op if recording.
static inline void sr_emit(SortTrace *t, uint8_t pos, uint16_t val) {
    t->moves++;
    if (t->ops && t->nops < t->cap)
        t->ops[t->nops++] = (uint16_t)(((uint16_t)pos << 8) | (val & 0xFFu));
}

static inline void sr_swap(uint16_t *a, uint8_t i, uint8_t j, SortTrace *t) {
    uint16_t tmp = a[i]; a[i] = a[j]; a[j] = tmp;
    sr_emit(t, i, a[i]);
    sr_emit(t, j, a[j]);
}

// ---------------------------------------------------------------------------------------------
// Recursive Hoare quicksort — the primary recursion witness (mid-element pivot bounds depth).

__attribute__((noinline))
static void sr_qsort(uint16_t *a, int16_t lo, int16_t hi, SortTrace *t) {
    if (lo >= hi) return;
    uint16_t pivot = a[((uint16_t)(lo + hi)) >> 1];
    int16_t i = lo, j = hi;
    while (i <= j) {
        while (a[i] < pivot) { i++; t->cmps++; }
        t->cmps++;
        while (a[j] > pivot) { j--; t->cmps++; }
        t->cmps++;
        if (i <= j) {
            if (i != j) sr_swap(a, (uint8_t)i, (uint8_t)j, t);
            i++; j--;
        }
    }
    sr_qsort(a, lo, j, t);      // genuine self-recursion (value live across the jsr)
    sr_qsort(a, i, hi, t);
}

// ---------------------------------------------------------------------------------------------
// Recursive top-down mergesort — second recursion witness; out-of-place via tmp[].

__attribute__((noinline))
static void sr_msort(uint16_t *a, uint16_t *tmp, int16_t lo, int16_t hi, SortTrace *t) {
    if (hi <= lo) return;
    int16_t mid = (int16_t)(((uint16_t)(lo + hi)) >> 1);
    sr_msort(a, tmp, lo, mid, t);
    sr_msort(a, tmp, (int16_t)(mid + 1), hi, t);
    int16_t i = lo, j = (int16_t)(mid + 1), k = lo;
    while (i <= mid && j <= hi) {
        t->cmps++;
        if (a[i] <= a[j]) tmp[k++] = a[i++];
        else              tmp[k++] = a[j++];
    }
    while (i <= mid) tmp[k++] = a[i++];
    while (j <= hi)  tmp[k++] = a[j++];
    for (k = lo; k <= hi; k++) { a[k] = tmp[k]; sr_emit(t, (uint8_t)k, a[k]); }
}

// ---------------------------------------------------------------------------------------------
// Iterative heapsort — the non-recursive contrast (loop-based sift-down).

static void sr_sift(uint16_t *a, int16_t lo, int16_t hi, SortTrace *t) {
    int16_t root = lo;
    for (;;) {
        int16_t child = (int16_t)(2 * root + 1);
        if (child > hi) break;
        if (child + 1 <= hi) { t->cmps++; if (a[child] < a[child + 1]) child++; }
        t->cmps++;
        if (a[root] < a[child]) { sr_swap(a, (uint8_t)root, (uint8_t)child, t); root = child; }
        else break;
    }
}

static void sr_hsort(uint16_t *a, int16_t n, SortTrace *t) {
    for (int16_t s = (int16_t)((n - 2) / 2); s >= 0; s--) sr_sift(a, s, (int16_t)(n - 1), t);
    for (int16_t e = (int16_t)(n - 1); e > 0; e--) {
        sr_swap(a, 0, (uint8_t)e, t);
        sr_sift(a, 0, (int16_t)(e - 1), t);
    }
}

// ---------------------------------------------------------------------------------------------
// xorshift16 RNG + Fisher-Yates shuffle (the same 3-tap used across the battery).

static inline uint16_t sr_rng16(uint16_t *st) {
    uint16_t x = *st;
    x ^= (uint16_t)(x << 7);
    x ^= (uint16_t)(x >> 9);
    x ^= (uint16_t)(x << 8);
    *st = x;
    return x;
}

// Fill a[0..n-1] with 0..n-1, then shuffle in place.
static void sr_shuffle(uint16_t *a, uint8_t n, uint16_t *st) {
    for (uint8_t i = 0; i < n; i++) a[i] = (uint16_t)i;
    for (uint8_t i = (uint8_t)(n - 1); i > 0; i--) {
        uint8_t   j   = (uint8_t)(sr_rng16(st) % (uint16_t)(i + 1u));
        uint16_t  tmp = a[i]; a[i] = a[j]; a[j] = tmp;
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold.

static inline uint16_t sr_fold(uint16_t h, uint16_t v) {
    uint16_t hi = (uint16_t)((h >> 15) & 1u);
    return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ v);
}

// ---------------------------------------------------------------------------------------------
// Differential gate CRC.
//
// SR_GATE_ROUNDS rounds; each shuffles a fresh permutation (deterministic seed), sorts three
// independent copies, asserts all three equal the identity 0..N-1 (self-check — a miscompiled
// sort that produces a wrong order is caught here, not just by the host/target hash diff), then
// folds each algorithm's (cmps ^ moves) fingerprint. ops=NULL throughout (counts only).
__attribute__((noinline))
static uint16_t sortrace_gate_crc(void) {
    uint16_t h  = 0;
    uint16_t st = 0xBEEFu;
    uint16_t base[SR_N], q[SR_N], hh[SR_N], mm[SR_N], tmp[SR_N];
    for (uint16_t r = 0; r < (uint16_t)SR_GATE_ROUNDS; r++) {
        sr_shuffle(base, (uint8_t)SR_N, &st);
        for (uint8_t i = 0; i < SR_N; i++) { q[i] = base[i]; hh[i] = base[i]; mm[i] = base[i]; }

        SortTrace tq, th, tm;
        sr_trace_init(&tq, 0, 0);
        sr_trace_init(&th, 0, 0);
        sr_trace_init(&tm, 0, 0);
        sr_qsort(q,  0, (int16_t)(SR_N - 1), &tq);
        sr_hsort(hh, (int16_t)SR_N,          &th);
        sr_msort(mm, tmp, 0, (int16_t)(SR_N - 1), &tm);

        uint16_t ok = 1u;
        for (uint8_t i = 0; i < SR_N; i++)
            if (q[i] != (uint16_t)i || hh[i] != (uint16_t)i || mm[i] != (uint16_t)i) ok = 0u;

        h = sr_fold(h, ok ? 0xA5A5u : 0xDEADu);
        h = sr_fold(h, (uint16_t)(tq.cmps ^ tq.moves));
        h = sr_fold(h, (uint16_t)(th.cmps ^ th.moves));
        h = sr_fold(h, (uint16_t)(tm.cmps ^ tm.moves));
    }
    return h;
}

#endif /* SORT_RACE_H */
