// Shared, PURE Fenwick tree (binary-indexed tree) — host-linkable, no hardware.  Demo #63.
//
// The codegen corner: the **`i & -i` low-bit-isolation two's-complement trick** in a dynamic prefix-sum
// loop.  A Fenwick tree maintains prefix sums under point updates in O(log n): `update` walks
// `i += i & -i` (add the lowest set bit) up the tree; `query` walks `i -= i & -i` down.  That `i & -i`
// idiom — mask a value with its own two's-complement negation to isolate the lowest 1-bit — is a codegen
// shape nothing in the first 62 demos emits.
//
// The demo integrates a live signal: a moving bump updates a handful of bins each frame (point updates),
// and the running prefix sum (the integral) is drawn as a rising staircase — recomputed via BIT queries.
//
// WIDTH DISCIPLINE: indices/values are uint16.  The low-bit is computed width-safely as
// `(uint16_t)(i & (uint16_t)(0u - i))` — `0u - i` is two's-complement-mod-2^16 after the uint16 cast on
// BOTH host (int=32) and target (int=16), so `i & -i` is bit-identical.  See docs/plans/2026-06-30-63-snes-fenwick.md.
#ifndef FENWICK_H
#define FENWICK_H

#include <stdint.h>

#ifndef FW_N
#define FW_N 16u              // number of bins (1-indexed 1..FW_N; one per display column)
#endif

typedef struct {
    int16_t tree[FW_N + 1u];  // 1-indexed BIT
    int16_t val[FW_N + 1u];   // current bin values (for point-update deltas)
} Fenwick;

// Isolate the lowest set bit of i, width-safe (identical on int=16 target and int=32 host).
static inline uint16_t fw_lowbit(uint16_t i) {
    return (uint16_t)(i & (uint16_t)(0u - i));
}

static void fw_clear(Fenwick *f) {
    for (uint16_t i = 0u; i <= FW_N; i++) { f->tree[i] = 0; f->val[i] = 0; }
}

// Add delta to bin i (1-indexed): walk up via i += i & -i.
static void fw_add(Fenwick *f, uint16_t i, int16_t delta) {
    f->val[i] = (int16_t)(f->val[i] + delta);
    for (; i <= FW_N; i += fw_lowbit(i))
        f->tree[i] = (int16_t)(f->tree[i] + delta);
}

// Set bin i to value v (point update via the delta).
static inline void fw_set(Fenwick *f, uint16_t i, int16_t v) {
    fw_add(f, i, (int16_t)(v - f->val[i]));
}

// Prefix sum of bins 1..i: walk down via i -= i & -i.
static int16_t fw_prefix(Fenwick *f, uint16_t i) {
    int16_t s = 0;
    for (; i > 0u; i -= fw_lowbit(i))
        s = (int16_t)(s + f->tree[i]);
    return s;
}

// Range sum [l, r] (1-indexed inclusive).
static inline int16_t fw_range(Fenwick *f, uint16_t l, uint16_t r) {
    return (int16_t)(fw_prefix(f, r) - fw_prefix(f, (uint16_t)(l - 1u)));
}

// A moving-bump signal: bin value at (i, t) — a triangular bump centred at (t mod FW_N).
static inline int16_t fw_signal(uint16_t i, uint16_t t) {
    uint16_t c = (uint16_t)(t % FW_N) + 1u;
    uint16_t d = (uint16_t)((i > c) ? (i - c) : (c - i));
    int16_t v = (int16_t)(8 - (int16_t)d);
    return (int16_t)((v > 0) ? v : 0);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t fw_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 120u
#endif

// Fold prefix sums + range sums as the bump moves.  Cross-check: the BIT prefix must equal a plain
// linear prefix sum of the same bins (an INDEPENDENT reference), folded too — so a wrong `i & -i` walk
// diverges.  Also folds fw_lowbit directly across a range so the bit trick itself is exercised.
static int16_t fw_prefix_ref(Fenwick *f, uint16_t i) {   // reference: linear sum of val[1..i]
    int16_t s = 0;
    for (uint16_t k = 1u; k <= i; k++) s = (int16_t)(s + f->val[k]);
    return s;
}

static uint16_t fenwick_gate_crc(void) {
    static Fenwick f;
    fw_clear(&f);
    uint16_t h = 0u;
    for (uint16_t t = 0u; t < (uint16_t)GATE_N; t++) {
        for (uint16_t i = 1u; i <= FW_N; i++) fw_set(&f, i, fw_signal(i, t));   // point updates
        for (uint16_t i = 1u; i <= FW_N; i += 5u) {
            int16_t p  = fw_prefix(&f, i);
            int16_t pr = fw_prefix_ref(&f, i);          // must equal p
            h = fw_fold(h, (uint16_t)p);
            h = fw_fold(h, (uint16_t)pr);
            h = fw_fold(h, (uint16_t)fw_range(&f, i, FW_N));
        }
        h = fw_fold(h, fw_lowbit((uint16_t)(t + 1u)));  // exercise the bit trick directly
    }
    return h;
}

#endif /* FENWICK_H */
