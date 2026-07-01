// Shared, PURE Levenshtein edit-distance DP — host-linkable, no hardware.  Demo #66.
//
// The codegen corner: a **2-D dynamic-programming table** — a doubly-indexed memoised recurrence with
// data-dependent min reductions and a backtrack pointer walk.  D[i][j] = the edit distance between the
// first i chars of A and first j chars of B:
//   D[i][j] = min(D[i-1][j]+1, D[i][j-1]+1, D[i-1][j-1] + (A[i-1]!=B[j-1]))
// then the optimal alignment is traced by walking back from D[m][n] to D[0][0].  Nothing in the first 65
// demos fills a 2-D DP table (true `D[i][j]` addressing) with a min-recurrence + backtrack.
//
// WIDTH DISCIPLINE: the table and strings are uint8; all integer -> bit-exact host vs target.
// See docs/plans/2026-06-30-66-snes-editdist.md.
#ifndef EDITDIST_H
#define EDITDIST_H

#include <stdint.h>

#ifndef ED_MAX
#define ED_MAX 15u              // max string length (table is (ED_MAX+1) x (ED_MAX+1))
#endif
#define ED_DIM (ED_MAX + 1u)

typedef struct {
    uint8_t D[ED_DIM][ED_DIM];  // 2-D DP table
    uint8_t path[ED_DIM][ED_DIM]; // 1 where the optimal alignment path passes
    uint8_t m, n;               // string lengths in use
    uint8_t dist;               // D[m][n]
} EditDist;

static inline uint8_t ed_min3(uint8_t a, uint8_t b, uint8_t c) {
    uint8_t r = (a < b) ? a : b;
    return (r < c) ? r : c;
}

// Fill the DP table for A[0..m) vs B[0..n).
static void ed_fill(EditDist *e, const uint8_t *a, uint8_t m, const uint8_t *b, uint8_t n) {
    e->m = m; e->n = n;
    for (uint8_t i = 0u; i <= m; i++) e->D[i][0] = i;
    for (uint8_t j = 0u; j <= n; j++) e->D[0][j] = j;
    for (uint8_t i = 1u; i <= m; i++)
        for (uint8_t j = 1u; j <= n; j++) {
            uint8_t sub = (uint8_t)(e->D[i - 1u][j - 1u] + ((a[i - 1u] != b[j - 1u]) ? 1u : 0u));
            uint8_t del = (uint8_t)(e->D[i - 1u][j] + 1u);
            uint8_t ins = (uint8_t)(e->D[i][j - 1u] + 1u);
            e->D[i][j] = ed_min3(sub, del, ins);
        }
    e->dist = e->D[m][n];
}

// Backtrack the optimal alignment from (m,n) to (0,0), marking path[][].
static void ed_backtrack(EditDist *e, const uint8_t *a, const uint8_t *b) {
    for (uint8_t i = 0u; i < ED_DIM; i++)
        for (uint8_t j = 0u; j < ED_DIM; j++) e->path[i][j] = 0u;
    uint8_t i = e->m, j = e->n;
    e->path[i][j] = 1u;
    while (i != 0u || j != 0u) {
        if (i == 0u) { j--; }
        else if (j == 0u) { i--; }
        else {
            uint8_t cost = (a[i - 1u] != b[j - 1u]) ? 1u : 0u;
            if (e->D[i][j] == (uint8_t)(e->D[i - 1u][j - 1u] + cost)) { i--; j--; }
            else if (e->D[i][j] == (uint8_t)(e->D[i - 1u][j] + 1u)) { i--; }
            else { j--; }
        }
        e->path[i][j] = 1u;
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t ed_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 40u
#endif

static uint16_t ed_rng(uint16_t *s) {
    uint16_t x = *s; x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 8);
    *s = x; return x;
}

// Fold the edit distance + table checksum + path length over GATE_N random string pairs.  Cross-check
// baked in: edit(A,B) must equal edit(B,A) (symmetry) — fold both, a mismatch diverges.  A miscompile in
// the 2-D indexing, the min-recurrence, or the backtrack diverges.
static uint16_t editdist_gate_crc(void) {
    static EditDist e, e2;
    uint16_t h = 0u, rng = 0x77AAu;
    for (uint16_t t = 0u; t < (uint16_t)GATE_N; t++) {
        uint8_t a[ED_MAX], b[ED_MAX];
        uint8_t m = (uint8_t)(4u + (ed_rng(&rng) % (ED_MAX - 4u)));
        uint8_t n = (uint8_t)(4u + (ed_rng(&rng) % (ED_MAX - 4u)));
        for (uint8_t i = 0u; i < m; i++) a[i] = (uint8_t)('A' + (ed_rng(&rng) % 4u));
        for (uint8_t j = 0u; j < n; j++) b[j] = (uint8_t)('A' + (ed_rng(&rng) % 4u));
        ed_fill(&e, a, m, b, n);
        ed_backtrack(&e, a, b);
        ed_fill(&e2, b, n, a, m);                            // symmetric: edit(B,A) == edit(A,B)
        uint16_t sum = 0u, plen = 0u;
        for (uint8_t i = 0u; i <= m; i++)
            for (uint8_t j = 0u; j <= n; j++) { sum = (uint16_t)(sum + e.D[i][j]); plen = (uint16_t)(plen + e.path[i][j]); }
        h = ed_fold(h, (uint16_t)e.dist);
        h = ed_fold(h, (uint16_t)(e.dist ^ e2.dist));        // 0 if symmetric
        h = ed_fold(h, sum);
        h = ed_fold(h, plen);
    }
    return h;
}

#endif /* EDITDIST_H */
