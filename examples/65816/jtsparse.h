// Sparse Switch Ladder (#153) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster C — the boundary and width escalations.
//
// THE ESCALATION: a switch has THREE lowering strategies on this target, not two. #142 jt256
// compiled the `else` arm of `legalizeBrJt`, #152 jtedge pinned the `<= 128` boundary between
// the two arms — but BOTH arms are jump tables, and both are downstream of the optimizer having
// already decided to build a table at all. When the case values are too sparse to tabulate, the
// switch never reaches `legalizeBrJt`: it is lowered to a **binary-search compare tree** before
// the backend sees a jump table. No demo across #1-#152 forces that strategy deliberately.
//
// MEASURED BEFORE THE DEMO WAS WRITTEN: a 12-case switch on a uint16_t with keys spread over
// 0..55555 emits ZERO `.LJTI` references and a signed-comparison narrowing tree — `cmp #57` /
// `sbc #5` (against 1337), then `cpy #100` (100), then `cpx #156` / `cpy #64` (40000 = $9C40) —
// i.e. a genuine binary search over 16-bit keys, -verify-machineinstrs clean.
//
// MECHANISM: two noinline dispatchers over the SAME sixteen handler bodies.
//
//   js_dense(idx)   cases 0..15                        -> jump table (strategy 1)
//   js_sparse(key)  the same sixteen handlers at keys
//                   0, 97, 250, ... 55555              -> compare tree (strategy 3)
//
// Every logical operation is executed through BOTH, over two independent copies of the same VM
// state, so the two strategies are differentially checked against each other inside one
// program: they must be indistinguishable. Both are also fed deliberate non-keys so both
// default arms are live — a compare tree's default is the fall-out of the whole search, a
// structurally different thing from a jump table's range check.
//
// DIFFERENTIAL: integer-exact. The CRC folds both final VM states, both traces, the miss counts
// and an explicit agreement flag.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md.

#ifndef JTSPARSE_H
#define JTSPARSE_H

#include <stdint.h>

#define JS_STEPS  384u
#define JS_TRACE  128u

typedef struct {
    uint16_t r[4];
    uint16_t acc;
    uint16_t miss;      /* default-arm hits — deliberately non-zero, and must MATCH */
} JsVm;

/* The sixteen sparse keys. Deliberately irregular gaps (3 to 15555) so no affine index can be
   recovered and no dense subrange is large enough to tabulate. */
static const uint16_t js_key[16] = {
        0u,    97u,   250u,   611u,
     1000u,  1337u,  2599u,  4096u,
     6143u,  9001u, 12345u, 17777u,
    20000u, 31415u, 40000u, 55555u
};
/* Values that are NOT keys, to drive both default arms. */
static const uint16_t js_nonkey[8] = {
       1u,   96u,  1336u,  4097u, 9000u, 12346u, 31416u, 65535u
};

static JsVm     js_vm[2];              /* [0] = dense, [1] = sparse */
static uint16_t js_prog[JS_STEPS];     /* the index stream, 0..15 = key, 16..23 = non-key */
static uint8_t  js_tx[2][JS_TRACE];
static uint8_t  js_ty[2][JS_TRACE];
static uint16_t js_nplot;
static uint16_t js_disagree;           /* MUST be 0 */

static uint16_t js_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}
static uint16_t js_rol(uint16_t v, uint8_t n) {
    n = (uint8_t)(n & 15u);
    if (n == (uint8_t)0u) return v;
    return (uint16_t)((uint16_t)(v << n) | (uint16_t)(v >> (uint8_t)(16u - n)));
}

/* --- the sixteen handler bodies, shared verbatim by both dispatchers --- */
#define JS_BODY(N)                                                                        \
    do {                                                                                  \
        switch (N) {                                                                      \
        case  0: m->r[0] = (uint16_t)(m->r[0] + (uint16_t)(m->r[1] + 0x11u)); break;       \
        case  1: m->r[1] = (uint16_t)(m->r[1] - (uint16_t)(m->r[2] + 0x23u)); break;       \
        case  2: m->r[2] = (uint16_t)(m->r[2] ^ (uint16_t)(m->r[3] + 0x37u)); break;       \
        case  3: m->r[3] = (uint16_t)(js_mul(m->r[3], 0x4Du) + m->r[0]); break;            \
        case  4: m->r[0] = (uint16_t)(js_rol(m->r[0], 3u) ^ m->r[2]); break;               \
        case  5: m->r[1] = (uint16_t)((uint16_t)(m->r[1] >> 3) + m->r[3]); break;          \
        case  6: m->acc  = (uint16_t)(m->acc + (uint16_t)(0x6Bu ^ m->r[0]));               \
                 m->r[2] = (uint16_t)(m->r[2] + m->acc); break;                            \
        case  7: { uint16_t o = (uint16_t)(m->r[1] + 0x7Fu);                               \
                   if (o < m->r[3]) m->r[3] = o; } break;                                  \
        case  8: { uint16_t o = (uint16_t)(m->r[2] + 0x91u);                               \
                   if (o > m->r[0]) m->r[0] = o; } break;                                  \
        case  9: m->acc  = (uint16_t)(js_mul(m->acc, 0xA3u) + m->r[1]);                    \
                 m->r[1] = (uint16_t)(m->r[1] ^ m->acc); break;                            \
        case 10: { uint16_t t = m->r[0]; m->r[0] = (uint16_t)(m->r[3] + 0xB7u);            \
                   m->r[3] = t; } break;                                                   \
        case 11: m->r[2] = (uint16_t)(m->r[2] & (uint16_t)(m->r[1] | 0xC5u)); break;       \
        case 12: m->r[3] = (uint16_t)(m->r[3] | (uint16_t)(m->r[2] + 0xD9u)); break;       \
        case 13: m->r[0] = (uint16_t)((uint16_t)(0xE3u << 3) - m->r[1]); break;            \
        case 14: m->r[1] = (uint16_t)(m->r[1] + (uint16_t)(js_rol(m->r[2], 5u) ^ 0xF1u));  \
                 break;                                                                    \
        default: m->acc  = (uint16_t)(m->acc ^ (uint16_t)(m->r[3] + 0xFDu));               \
                 m->r[2] = (uint16_t)(m->r[2] - m->acc); break;                            \
        }                                                                                  \
    } while (0)

/* --- strategy 1: dense 0..15 -> jump table --- */
__attribute__((noinline))
static void js_dense(JsVm *m, uint16_t idx) {
    switch (idx) {
    case  0: JS_BODY( 0); break;
    case  1: JS_BODY( 1); break;
    case  2: JS_BODY( 2); break;
    case  3: JS_BODY( 3); break;
    case  4: JS_BODY( 4); break;
    case  5: JS_BODY( 5); break;
    case  6: JS_BODY( 6); break;
    case  7: JS_BODY( 7); break;
    case  8: JS_BODY( 8); break;
    case  9: JS_BODY( 9); break;
    case 10: JS_BODY(10); break;
    case 11: JS_BODY(11); break;
    case 12: JS_BODY(12); break;
    case 13: JS_BODY(13); break;
    case 14: JS_BODY(14); break;
    case 15: JS_BODY(15); break;
    default: m->miss = (uint16_t)(m->miss + 1u); break;
    }
}

/* --- strategy 3: the SAME sixteen bodies at sparse keys -> binary-search compare tree --- */
__attribute__((noinline))
static void js_sparse(JsVm *m, uint16_t key) {
    switch (key) {
    case     0u: JS_BODY( 0); break;
    case    97u: JS_BODY( 1); break;
    case   250u: JS_BODY( 2); break;
    case   611u: JS_BODY( 3); break;
    case  1000u: JS_BODY( 4); break;
    case  1337u: JS_BODY( 5); break;
    case  2599u: JS_BODY( 6); break;
    case  4096u: JS_BODY( 7); break;
    case  6143u: JS_BODY( 8); break;
    case  9001u: JS_BODY( 9); break;
    case 12345u: JS_BODY(10); break;
    case 17777u: JS_BODY(11); break;
    case 20000u: JS_BODY(12); break;
    case 31415u: JS_BODY(13); break;
    case 40000u: JS_BODY(14); break;
    case 55555u: JS_BODY(15); break;
    default: m->miss = (uint16_t)(m->miss + 1u); break;
    }
}

/* Index stream: 0..15 select a key, 16..23 select a deliberate non-key so both default arms
   are exercised. Two coprime strides sweep both populations. */
static void js_program(void) {
    uint16_t a = (uint16_t)0u, b = (uint16_t)5u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JS_STEPS; i++) {
        if ((i % 5u) == 4u) { js_prog[i] = (uint16_t)(16u + (b % 8u)); b = (uint16_t)(b + 3u); }
        else                { js_prog[i] = (uint16_t)(a % 16u);        a = (uint16_t)(a + 7u); }
    }
}

static uint16_t js_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(js_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: drive both strategies with the same logical work and fold everything.
// --------------------------------------------------------------------------
static uint16_t jtsparse_gate_crc(void) {
    uint16_t h = (uint16_t)0x5E27u;

    for (uint8_t v = (uint8_t)0u; v < (uint8_t)2u; v++) {
        js_vm[v].r[0] = (uint16_t)0x0137u; js_vm[v].r[1] = (uint16_t)0x7B21u;
        js_vm[v].r[2] = (uint16_t)0x4E09u; js_vm[v].r[3] = (uint16_t)0xC0DEu;
        js_vm[v].acc  = (uint16_t)0xA5A5u;
        js_vm[v].miss = (uint16_t)0u;
    }
    js_nplot = (uint16_t)0u;
    js_disagree = (uint16_t)0u;
    js_program();

    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JS_STEPS; i++) {
        uint16_t sel = js_prog[i];
        if (sel < (uint16_t)16u) {
            js_dense(&js_vm[0], sel);
            js_sparse(&js_vm[1], js_key[(uint8_t)sel]);
        } else {
            /* a non-index for the dense dispatcher, a non-key for the sparse one */
            js_dense(&js_vm[0], (uint16_t)(100u + sel));
            js_sparse(&js_vm[1], js_nonkey[(uint8_t)(sel - 16u)]);
        }
        for (uint8_t k = (uint8_t)0u; k < (uint8_t)4u; k++)
            if (js_vm[0].r[k] != js_vm[1].r[k]) js_disagree = (uint16_t)(js_disagree + 1u);
        if (js_vm[0].acc != js_vm[1].acc || js_vm[0].miss != js_vm[1].miss)
            js_disagree = (uint16_t)(js_disagree + 1u);
        if (js_nplot < (uint16_t)JS_TRACE) {
            for (uint8_t v = (uint8_t)0u; v < (uint8_t)2u; v++) {
                js_tx[v][js_nplot] = (uint8_t)((js_vm[v].r[0] >> 9) & 0x7Fu);
                js_ty[v][js_nplot] = (uint8_t)((js_vm[v].r[1] >> 9) & 0x7Fu);
            }
            js_nplot++;
        }
    }

    for (uint8_t v = (uint8_t)0u; v < (uint8_t)2u; v++) {
        for (uint8_t k = (uint8_t)0u; k < (uint8_t)4u; k++) h = js_mix(h, js_vm[v].r[k]);
        h = js_mix(h, js_vm[v].acc);
        h = js_mix(h, js_vm[v].miss);
        for (uint16_t i = (uint16_t)0u; i < js_nplot; i++)
            h = js_mix(h, (uint16_t)((uint16_t)js_tx[v][i] | (uint16_t)((uint16_t)js_ty[v][i] << 8)));
    }
    h = js_mix(h, js_disagree);
    return h;
}

/* Cross-checks the gate asserts: the two strategies must agree at every step, and both default
   arms must genuinely have been taken (an all-hit stream would leave the miss path untested). */
static uint16_t js_disagreements(void) { return js_disagree; }
static uint16_t js_dense_misses(void)  { return js_vm[0].miss; }
static uint16_t js_sparse_misses(void) { return js_vm[1].miss; }

#endif /* JTSPARSE_H */
