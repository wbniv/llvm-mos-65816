// Jump-Table Boundary Sweep (#152) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster C — the boundary and width escalations.
//
// THE ESCALATION: #142 jt256 compiled the `else` arm of `legalizeBrJt` for the first time, at
// 256 successors — twice the limit, deep past the boundary. This demo sits ON the boundary.
// The size gate is (MOSLegalizerInfo.cpp:3334):
//
//     if (STI.hasJMPIdxIndir() && Table.MBBs.size() <= 128) {   /* JMP (abs,X)          */
//     } else {                                                  /* split lo/hi + MO_HI_JT */
//
// Boundary off-by-one is the classic failure of a size-gated lowering, and before this demo no
// test in the tree sat anywhere near 128 — the five jump tables across #1-#141 are 8-16-case VM
// dispatches, and #142 is 256.
//
// MEASURED BEFORE THE DEMO WAS WRITTEN (five probe dispatchers, one TU, -Os, -verify clean):
//
//     126 successors -> jmp (.LJTI1_0,x)                                  JMPIdxIndir
//     127 successors -> jmp (.LJTI2_0,x)                                  JMPIdxIndir
//     128 successors -> jmp (.LJTI3_0,x)                                  JMPIdxIndir
//     129 successors -> lda .LJTI4_0,x + lda .LJTI4_0+256,x + jmp (__rc2) split lo/hi
//     130 successors -> lda .LJTI5_0,x + lda .LJTI5_0+256,x + jmp (__rc2) split lo/hi
//
// **The boundary is exact and inclusive at 128 — there is no off-by-one.** So this demo ships
// as a positive with a negative attached: the bug it was built to find is not there. It is
// still the only test in the tree that pins the constant from both sides, and it records one
// measured detail no prior demo does — the split arm's high table is addressed at a FIXED
// `+256` from the low one, independent of the real entry count.
//
// MECHANISM: three noinline dispatchers over the SAME sixteen handler families, with 127, 128
// and 129 distinct successors. Every arm carries its own case value as the family's immediate,
// so no two arms can merge and the emitted table has exactly one entry per case (the gate
// checks that rather than assuming it). All three are then fed the SAME opcode stream,
// restricted to 0..126 so every opcode is in range for all three, over three independent copies
// of the same VM state. ALL THREE MUST AGREE. A boundary off-by-one that mis-indexed either arm
// by one slot lands in a neighbouring handler and moves exactly one of the three.
//
// DIFFERENTIAL: integer-exact. The CRC folds all three final VM states, all three traces and an
// explicit three-way agreement flag.
// WIDTH DISCIPLINE: explicit uint8/16/32; every multiply goes through uint32_t.
// See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md.

#ifndef JTEDGE_H
#define JTEDGE_H

#include <stdint.h>

#define JE_STEPS  381u   /* opcodes executed per dispatcher (3 * 127, whole sweeps) */
#define JE_TRACE  128u   /* plotted points per dispatcher                           */

typedef struct {
    uint16_t r[4];
    uint16_t acc;
    uint16_t miss;      /* default-arm hits — MUST stay 0 in a gate run */
} JeVm;

static JeVm     je_vm[3];                 /* one per dispatcher: 127, 128, 129 */
static uint8_t  je_prog[JE_STEPS];
static uint8_t  je_tx[3][JE_TRACE];
static uint8_t  je_ty[3][JE_TRACE];
static uint16_t je_nplot;
static uint16_t je_disagree;              /* steps at which the three diverged — MUST be 0 */

static uint16_t je_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}
static uint16_t je_rol(uint16_t v, uint8_t n) {
    n = (uint8_t)(n & 15u);
    if (n == (uint8_t)0u) return v;
    return (uint16_t)((uint16_t)(v << n) | (uint16_t)(v >> (uint8_t)(16u - n)));
}

/* --- the sixteen operation families; d, s and k are literals at every call site --- */
static void je_f0(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(m->r[d] + (uint16_t)(m->r[s] + k)); }
static void je_f1(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(m->r[d] - (uint16_t)(m->r[s] + k)); }
static void je_f2(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(m->r[d] ^ (uint16_t)(m->r[s] + k)); }
static void je_f3(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(je_mul(m->r[d], (uint16_t)((k << 1) | 1u)) + m->r[s]); }
static void je_f4(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(je_rol(m->r[d], (uint8_t)(k & 15u)) ^ m->r[s]); }
static void je_f5(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)((uint16_t)(m->r[d] >> (uint8_t)((k & 7u) + 1u)) + m->r[s]); }
static void je_f6(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->acc = (uint16_t)(m->acc + (uint16_t)(k ^ m->r[s])); m->r[d] = (uint16_t)(m->r[d] + m->acc); }
static void je_f7(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { uint16_t o = (uint16_t)(m->r[s] + k); if (o < m->r[d]) m->r[d] = o; }
static void je_f8(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { uint16_t o = (uint16_t)(m->r[s] + k); if (o > m->r[d]) m->r[d] = o; }
static void je_f9(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->acc = (uint16_t)(je_mul(m->acc, (uint16_t)((k << 1) | 1u)) + m->r[s]); m->r[d] = (uint16_t)(m->r[d] ^ m->acc); }
static void je_fA(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { uint16_t t = m->r[d]; m->r[d] = (uint16_t)(m->r[s] + k); m->r[s] = t; }
static void je_fB(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(m->r[d] & (uint16_t)(m->r[s] | k | 1u)); }
static void je_fC(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(m->r[d] | (uint16_t)(m->r[s] + k)); }
static void je_fD(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)((uint16_t)(k << 3) - m->r[s]); }
static void je_fE(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->r[d] = (uint16_t)(m->r[d] + (uint16_t)(je_rol(m->r[s], (uint8_t)(k & 7u)) ^ k)); }
static void je_fF(JeVm *m, uint8_t d, uint8_t s, uint16_t k) { m->acc = (uint16_t)(m->acc ^ (uint16_t)(m->r[s] + k)); m->r[d] = (uint16_t)(m->r[d] - m->acc); }

/* Family = (K >> 3) & 15 so BOTH the low and high bits of the case value pick the work; the
   immediate is the case value itself, so every one of the arms is a distinct block. */
#define JE_D(K) ((uint8_t)((K) & 3u))
#define JE_S(K) ((uint8_t)(((K) >> 2) & 3u))
#define JE_K(K) ((uint16_t)(K))

#define JE_BODY(K)                                                          \
    do {                                                                    \
        switch (((K) >> 3) & 15) {  /* K is a literal — this folds away */  \
        case 0x0: je_f0(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x1: je_f1(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x2: je_f2(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x3: je_f3(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x4: je_f4(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x5: je_f5(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x6: je_f6(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x7: je_f7(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x8: je_f8(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0x9: je_f9(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0xA: je_fA(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0xB: je_fB(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0xC: je_fC(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0xD: je_fD(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        case 0xE: je_fE(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        default:  je_fF(m, JE_D(K), JE_S(K), JE_K(K)); break;               \
        }                                                                   \
    } while (0)

#define JE_CASE(K)  case (K): JE_BODY(K); break;
#define JE_ROW(B)   JE_CASE((B)+0x0) JE_CASE((B)+0x1) JE_CASE((B)+0x2) JE_CASE((B)+0x3) \
                    JE_CASE((B)+0x4) JE_CASE((B)+0x5) JE_CASE((B)+0x6) JE_CASE((B)+0x7) \
                    JE_CASE((B)+0x8) JE_CASE((B)+0x9) JE_CASE((B)+0xA) JE_CASE((B)+0xB) \
                    JE_CASE((B)+0xC) JE_CASE((B)+0xD) JE_CASE((B)+0xE) JE_CASE((B)+0xF)

/* --- 127 successors: one UNDER the limit -> JMP (abs,X) arm --- */
__attribute__((noinline))
static void je_d127(JeVm *m, uint8_t op) {
    switch (op) {
    JE_ROW(0x00) JE_ROW(0x10) JE_ROW(0x20) JE_ROW(0x30)
    JE_ROW(0x40) JE_ROW(0x50) JE_ROW(0x60)
    JE_CASE(0x70) JE_CASE(0x71) JE_CASE(0x72) JE_CASE(0x73)
    JE_CASE(0x74) JE_CASE(0x75) JE_CASE(0x76) JE_CASE(0x77)
    JE_CASE(0x78) JE_CASE(0x79) JE_CASE(0x7A) JE_CASE(0x7B)
    JE_CASE(0x7C) JE_CASE(0x7D) JE_CASE(0x7E)
    default: m->miss = (uint16_t)(m->miss + 1u); break;
    }
}

/* --- 128 successors: EXACTLY at the limit -> still the JMP (abs,X) arm --- */
__attribute__((noinline))
static void je_d128(JeVm *m, uint8_t op) {
    switch (op) {
    JE_ROW(0x00) JE_ROW(0x10) JE_ROW(0x20) JE_ROW(0x30)
    JE_ROW(0x40) JE_ROW(0x50) JE_ROW(0x60) JE_ROW(0x70)
    default: m->miss = (uint16_t)(m->miss + 1u); break;
    }
}

/* --- 129 successors: one OVER the limit -> split lo/hi byte tables + MO_HI_JT --- */
__attribute__((noinline))
static void je_d129(JeVm *m, uint8_t op) {
    switch (op) {
    JE_ROW(0x00) JE_ROW(0x10) JE_ROW(0x20) JE_ROW(0x30)
    JE_ROW(0x40) JE_ROW(0x50) JE_ROW(0x60) JE_ROW(0x70)
    JE_CASE(0x80)
    default: m->miss = (uint16_t)(m->miss + 1u); break;
    }
}

/* Opcode stream, every value in 0..126 so it is IN RANGE for all three dispatchers and the
   default arm is never taken. Two coprime strides sweep the whole shared range. */
static void je_program(void) {
    uint16_t a = (uint16_t)0u, b = (uint16_t)0x4Bu;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JE_STEPS; i++) {
        if ((i & 1u) == 0u) { je_prog[i] = (uint8_t)(a % 127u); a = (uint16_t)(a + 1u); }
        else                { je_prog[i] = (uint8_t)(b % 127u); b = (uint16_t)(b + 11u); }
    }
}

static uint16_t je_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(je_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: drive all three dispatchers with the same stream and fold everything.
// --------------------------------------------------------------------------
static uint16_t jtedge_gate_crc(void) {
    uint16_t h = (uint16_t)0x3CA1u;

    for (uint8_t v = (uint8_t)0u; v < (uint8_t)3u; v++) {
        je_vm[v].r[0] = (uint16_t)0x0137u; je_vm[v].r[1] = (uint16_t)0x7B21u;
        je_vm[v].r[2] = (uint16_t)0x4E09u; je_vm[v].r[3] = (uint16_t)0xC0DEu;
        je_vm[v].acc  = (uint16_t)0xA5A5u;
        je_vm[v].miss = (uint16_t)0u;
    }
    je_nplot = (uint16_t)0u;
    je_disagree = (uint16_t)0u;
    je_program();

    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JE_STEPS; i++) {
        uint8_t op = je_prog[i];
        je_d127(&je_vm[0], op);
        je_d128(&je_vm[1], op);
        je_d129(&je_vm[2], op);
        /* The three lowerings must be indistinguishable. */
        for (uint8_t k = (uint8_t)0u; k < (uint8_t)4u; k++) {
            if (je_vm[0].r[k] != je_vm[1].r[k] || je_vm[0].r[k] != je_vm[2].r[k])
                je_disagree = (uint16_t)(je_disagree + 1u);
        }
        if (je_vm[0].acc != je_vm[1].acc || je_vm[0].acc != je_vm[2].acc)
            je_disagree = (uint16_t)(je_disagree + 1u);
        if (je_nplot < (uint16_t)JE_TRACE) {
            for (uint8_t v = (uint8_t)0u; v < (uint8_t)3u; v++) {
                je_tx[v][je_nplot] = (uint8_t)((je_vm[v].r[0] >> 9) & 0x7Fu);
                je_ty[v][je_nplot] = (uint8_t)((je_vm[v].r[1] >> 9) & 0x7Fu);
            }
            je_nplot++;
        }
    }

    for (uint8_t v = (uint8_t)0u; v < (uint8_t)3u; v++) {
        for (uint8_t k = (uint8_t)0u; k < (uint8_t)4u; k++) h = je_mix(h, je_vm[v].r[k]);
        h = je_mix(h, je_vm[v].acc);
        h = je_mix(h, je_vm[v].miss);
        for (uint16_t i = (uint16_t)0u; i < je_nplot; i++)
            h = je_mix(h, (uint16_t)((uint16_t)je_tx[v][i] | (uint16_t)((uint16_t)je_ty[v][i] << 8)));
    }
    h = je_mix(h, je_disagree);
    return h;
}

/* Cross-checks the gate asserts: the three dispatchers must have agreed at every step, and no
   default arm may have been taken (an out-of-range opcode would make the comparison vacuous). */
static uint16_t je_disagreements(void) { return je_disagree; }
static uint16_t je_misses(void) {
    return (uint16_t)(je_vm[0].miss + je_vm[1].miss + je_vm[2].miss);
}

#endif /* JTEDGE_H */
