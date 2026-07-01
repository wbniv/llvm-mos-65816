// Shared, PURE union-find percolation — host-linkable, no hardware.  Demo #62.
//
// The codegen corner: a **disjoint-set (union-find) with path compression** — the classic `find` that
// chases parent pointers to a root AND rewrites every pointer on the path to point straight at the root
// (`parent[x] = root`), i.e. pointer-chasing with in-place update.  #18 (maze A*) used a flat-array heap;
// #31 (Barnes-Hut) built an append-only pooled tree; neither did the find-with-compression flatten idiom.
//
// The demo is bond percolation: cells start as singleton sets; random adjacent bonds union their sets;
// clusters merge until a top-row cell and a bottom-row cell land in the same set — the spanning cluster
// (the percolation phase transition).
//
// WIDTH DISCIPLINE: parent[] holds uint16 cell indices, rank[] uint8; all integer -> bit-exact host vs
// target.  The RNG and edge order are deterministic (seeded), so the whole evolution is reproducible.
// See docs/plans/2026-06-30-62-snes-percol.md.
#ifndef PERCOL_H
#define PERCOL_H

#include <stdint.h>

#ifndef PC_W
#define PC_W 16u
#endif
#ifndef PC_H
#define PC_H 16u
#endif
#define PC_N (PC_W * PC_H)

typedef struct {
    uint16_t parent[PC_N];
    uint8_t  rank[PC_N];
    uint16_t comps;          // number of disjoint components remaining
    uint16_t rng;
} Percol;

static inline uint16_t pc_rng(Percol *p) {
    uint16_t x = p->rng;
    x ^= (uint16_t)(x << 7); x ^= (uint16_t)(x >> 9); x ^= (uint16_t)(x << 8);
    p->rng = x; return x;
}

static void pc_init(Percol *p, uint16_t seed) {
    for (uint16_t i = 0u; i < PC_N; i++) { p->parent[i] = i; p->rank[i] = 0u; }
    p->comps = PC_N;
    p->rng = (uint16_t)(seed | 1u);
}

// find with FULL path compression: locate the root, then re-point every node on the path to it.
static uint16_t pc_find(Percol *p, uint16_t x) {
    uint16_t r = x;
    while (p->parent[r] != r) r = p->parent[r];      // walk to the root
    while (p->parent[x] != r) {                       // compress: flatten the path
        uint16_t nx = p->parent[x];
        p->parent[x] = r;
        x = nx;
    }
    return r;
}

// union by rank; returns 1 if the two sets were merged (were distinct).
static uint8_t pc_union(Percol *p, uint16_t a, uint16_t b) {
    uint16_t ra = pc_find(p, a), rb = pc_find(p, b);
    if (ra == rb) return 0u;
    if (p->rank[ra] < p->rank[rb]) { uint16_t t = ra; ra = rb; rb = t; }
    p->parent[rb] = ra;
    if (p->rank[ra] == p->rank[rb]) p->rank[ra]++;
    p->comps--;
    return 1u;
}

// Add one random bond (a horizontal or vertical edge between adjacent cells) and union its endpoints.
// Returns 1 if it merged two clusters.
static uint8_t pc_add_bond(Percol *p) {
    uint16_t r = pc_rng(p);
    uint16_t cell = (uint16_t)(r % PC_N);
    uint8_t horiz = (uint8_t)((r >> 15) & 1u);
    uint16_t x = (uint16_t)(cell % PC_W), y = (uint16_t)(cell / PC_W);
    uint16_t nb;
    if (horiz) { if (x + 1u >= PC_W) return 0u; nb = (uint16_t)(cell + 1u); }
    else       { if (y + 1u >= PC_H) return 0u; nb = (uint16_t)(cell + PC_W); }
    return pc_union(p, cell, nb);
}

// Does the top row connect to the bottom row (a spanning cluster)?
static uint8_t pc_percolates(Percol *p) {
    for (uint16_t tx = 0u; tx < PC_W; tx++) {
        uint16_t rt = pc_find(p, tx);
        for (uint16_t bx = 0u; bx < PC_W; bx++)
            if (pc_find(p, (uint16_t)((PC_H - 1u) * PC_W + bx)) == rt) return 1u;
    }
    return 0u;
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t pc_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 400u
#endif

// Add GATE_N random bonds; fold the component count and a couple of representative roots after each, plus
// the final percolation verdict and the full parent-array checksum.  A miscompile in the find/union
// pointer-chasing or the path compression diverges.
static uint16_t percol_gate_crc(void) {
    static Percol p;
    pc_init(&p, 0xC0DEu);
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        (void)pc_add_bond(&p);
        h = pc_fold(h, p.comps);
        h = pc_fold(h, pc_find(&p, (uint16_t)(i % PC_N)));    // a compressing find every step
    }
    h = pc_fold(h, (uint16_t)pc_percolates(&p));
    uint16_t sum = 0u;
    for (uint16_t i = 0u; i < PC_N; i++)
        sum = (uint16_t)(sum + (uint32_t)p.parent[i] * (uint32_t)(i + 1u));  // u32 mul -> no 16-bit UB
    h = pc_fold(h, sum);
    return h;
}

#endif /* PERCOL_H */
