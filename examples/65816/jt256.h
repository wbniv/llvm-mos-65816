// ISA-256 Bytecode Machine (#142) — shared, portable logic header.
//
// Round 8 (the un-entered backend paths), Cluster A. The corner: the **else arm of
// `legalizeBrJt`** (MOSLegalizerInfo.cpp:443 rule, handler ~3311). That handler has TWO
// implementations and picks between them on
//
//     if (STI.hasJMPIdxIndir() && Table.MBBs.size() <= 128)
//
// The taken arm emits `JMP (abs,X)` over one 2-byte-per-entry table. The OTHER arm — for a
// switch with MORE THAN 128 successors — cannot use `JMP (abs,X)` at all: it must index a
// low-byte table and a separate high-byte table (the latter under its own `MO_HI_JT`
// relocation flavour) with two `G_LOAD_ABS_IDX`, reassemble a 16-bit pointer, and
// `G_BRINDIRECT` through it.
//
// A coverage audit of demos #1-#141 found exactly FIVE that form a jump table at all
// (bf_vm, cordic, duff, perlin, turtle-vm) and ALL FIVE take the `JMP (abs,X)` arm: they are
// VM dispatches of 8-16 cases and a Duff's device of 8. The >128 arm has never been compiled
// by this project.
//
// MECHANISM: a genuine dense-dispatch interpreter. ISA-256 gives every one of the 256 opcode
// bytes its own handler, laid out like a real instruction set — the high nibble selects the
// operation family, the low nibble the destination/source register pair. 256 successors is
// 2x the threshold, so the dispatch cannot take the `JMP (abs,X)` arm no matter how the
// program is scheduled. The handlers do real, DIFFERENT work (a multiply is not a shift is
// not a memory access), which is also what stops SimplifyCFG collapsing the switch into a
// constant lookup table and quietly deleting the corner under test.
//
// The machine drives a plotter: r[0]/r[1] are read as a point after every instruction, so the
// executed program draws a phase portrait and a wrong dispatch is visible as well as
// CRC-divergent.
//
// DIFFERENTIAL: integer-exact. The gate CRC folds the final register file, the accumulator,
// all 256 bytes of VM memory, the whole plotted trace, and the opcode-coverage bitmap (which
// of the 256 handlers were actually entered) — a jump one table slot off lands in the wrong
// handler and moves all five.
// WIDTH DISCIPLINE: explicit uint8/16/32 everywhere; every multiply goes through uint32_t so
// host (32-bit int) and target (16-bit int) agree bit-for-bit with no signed overflow.
// See docs/plans/2026-09-16-round8-unentered-backend-paths.md.

#ifndef JT256_H
#define JT256_H

#include <stdint.h>

#define JT_MEM    256u   /* VM data memory, byte-addressed, wraps            */
#define JT_STEPS  512u   /* instructions executed per gate run               */
#define JT_TRACE  512u   /* plotted points (one per instruction)             */

typedef struct {
    uint16_t r[4];
    uint16_t acc;
    uint8_t  mem[JT_MEM];
} JtVm;

static JtVm     jt_vm;
static uint8_t  jt_prog[JT_STEPS];       /* the opcode stream that is executed */
static uint8_t  jt_seen[32];             /* 256-bit "this handler was entered" bitmap */
static uint8_t  jt_tx[JT_TRACE];         /* plotted trace, canvas space */
static uint8_t  jt_ty[JT_TRACE];
static uint16_t jt_nplot;

/* --- portable 16-bit primitives (no signed overflow on either host or target) --- */
static uint16_t jt_mul(uint16_t a, uint16_t b) {
    return (uint16_t)((uint32_t)a * (uint32_t)b);
}
static uint16_t jt_rol(uint16_t v, uint8_t n) {
    n = (uint8_t)(n & 15u);
    if (n == (uint8_t)0u) return v;
    return (uint16_t)((uint16_t)(v << n) | (uint16_t)(v >> (uint8_t)(16u - n)));
}
static uint8_t jt_ld8(const JtVm *m, uint16_t a) { return m->mem[(uint8_t)(a & 0xFFu)]; }
static void    jt_st8(JtVm *m, uint16_t a, uint8_t v) { m->mem[(uint8_t)(a & 0xFFu)] = v; }

// --------------------------------------------------------------------------
// The sixteen operation families. Each takes the destination register index, the source
// register index and the opcode byte itself as the family's immediate — all three are
// compile-time constants at every call site, so each of the 256 switch arms folds to a
// DISTINCT block of code (which is the whole point: 256 distinct successors).
// --------------------------------------------------------------------------
static void jt_f0(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* ADD  */
    m->r[d] = (uint16_t)(m->r[d] + (uint16_t)(m->r[s] + k));
}
static void jt_f1(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* SUB  */
    m->r[d] = (uint16_t)(m->r[d] - (uint16_t)(m->r[s] + k));
}
static void jt_f2(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* XOR  */
    m->r[d] = (uint16_t)(m->r[d] ^ (uint16_t)(m->r[s] + k));
}
static void jt_f3(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* MULK (odd multiplier) */
    m->r[d] = (uint16_t)(jt_mul(m->r[d], (uint16_t)((k << 1) | 1u)) + m->r[s]);
}
static void jt_f4(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* ROL  */
    m->r[d] = (uint16_t)(jt_rol(m->r[d], (uint8_t)(k & 15u)) ^ m->r[s]);
}
static void jt_f5(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* SHR  */
    m->r[d] = (uint16_t)((uint16_t)(m->r[d] >> (uint8_t)((k & 7u) + 1u)) + m->r[s]);
}
static void jt_f6(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* LD16 */
    uint16_t a = (uint16_t)(m->r[s] + k);
    m->r[d] = (uint16_t)((uint16_t)jt_ld8(m, a) |
                         (uint16_t)((uint16_t)jt_ld8(m, (uint16_t)(a + 1u)) << 8));
}
static void jt_f7(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* ST8  */
    jt_st8(m, (uint16_t)(m->r[d] + k), (uint8_t)(m->r[s] ^ k));
}
static void jt_f8(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* MIN  */
    uint16_t o = (uint16_t)(m->r[s] + k);
    if (o < m->r[d]) m->r[d] = o;
}
static void jt_f9(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* MAX  */
    uint16_t o = (uint16_t)(m->r[s] + k);
    if (o > m->r[d]) m->r[d] = o;
}
static void jt_fA(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* ACCMIX */
    m->acc  = (uint16_t)(jt_mul(m->acc, (uint16_t)((k << 1) | 1u)) + m->r[s]);
    m->r[d] = (uint16_t)(m->r[d] ^ m->acc);
}
static void jt_fB(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* SWAP */
    uint16_t t = m->r[d];
    m->r[d] = (uint16_t)(m->r[s] + k);
    m->r[s] = t;
}
static void jt_fC(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* AND  */
    m->r[d] = (uint16_t)(m->r[d] & (uint16_t)(m->r[s] | k | 1u));
}
static void jt_fD(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* OR   */
    m->r[d] = (uint16_t)(m->r[d] | (uint16_t)(m->r[s] + k));
}
static void jt_fE(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* NEG  */
    m->r[d] = (uint16_t)((uint16_t)(k << 3) - m->r[s]);
}
static void jt_fF(JtVm *m, uint8_t d, uint8_t s, uint16_t k) {   /* MIX  */
    m->acc  = (uint16_t)(m->acc + (uint16_t)(k ^ m->r[s]));
    m->r[d] = (uint16_t)(m->r[d] + m->acc);
}

/* d = op & 3, s = (op >> 2) & 3, family = op >> 4, immediate = op. All literal per arm. */
#define JT_D(K) ((uint8_t)((K) & 3u))
#define JT_S(K) ((uint8_t)(((K) >> 2) & 3u))
#define JT_K(K) ((uint16_t)(K))

#define JT_BODY(K)                                                              \
    do {                                                                        \
        switch ((K) >> 4) {   /* K is a literal — this selector folds away */    \
        case 0x0: jt_f0(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x1: jt_f1(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x2: jt_f2(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x3: jt_f3(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x4: jt_f4(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x5: jt_f5(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x6: jt_f6(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x7: jt_f7(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x8: jt_f8(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0x9: jt_f9(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0xA: jt_fA(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0xB: jt_fB(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0xC: jt_fC(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0xD: jt_fD(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        case 0xE: jt_fE(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        default:  jt_fF(m, JT_D(K), JT_S(K), JT_K(K)); break;                   \
        }                                                                       \
    } while (0)

#define JT_CASE(K)   case (K): JT_BODY(K); break;
#define JT_ROW(B)    JT_CASE((B)+0x0) JT_CASE((B)+0x1) JT_CASE((B)+0x2) JT_CASE((B)+0x3) \
                     JT_CASE((B)+0x4) JT_CASE((B)+0x5) JT_CASE((B)+0x6) JT_CASE((B)+0x7) \
                     JT_CASE((B)+0x8) JT_CASE((B)+0x9) JT_CASE((B)+0xA) JT_CASE((B)+0xB) \
                     JT_CASE((B)+0xC) JT_CASE((B)+0xD) JT_CASE((B)+0xE) JT_CASE((B)+0xF)

// THE DISPATCH UNDER TEST. 256 successors — more than double legalizeBrJt's `<= 128` limit,
// so the `JMP (abs,X)` arm is structurally unreachable and the split low/high byte-table arm
// must fire. noinline so the dispatch cannot be cloned or partially specialized away.
__attribute__((noinline))
static void jt_exec(JtVm *m, uint8_t op) {
    switch (op) {
    JT_ROW(0x00) JT_ROW(0x10) JT_ROW(0x20) JT_ROW(0x30)
    JT_ROW(0x40) JT_ROW(0x50) JT_ROW(0x60) JT_ROW(0x70)
    JT_ROW(0x80) JT_ROW(0x90) JT_ROW(0xA0) JT_ROW(0xB0)
    JT_ROW(0xC0) JT_ROW(0xD0) JT_ROW(0xE0) JT_ROW(0xF0)
    }
}

/* Build the opcode stream. Two interleaved strides coprime with 256 walk the whole opcode
   space, so every one of the 256 handlers is entered at least once in a JT_STEPS run. */
static void jt_program(void) {
    uint16_t a = (uint16_t)0u, b = (uint16_t)0x5Fu;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JT_STEPS; i++) {
        if ((i & 1u) == 0u) { jt_prog[i] = (uint8_t)(a & 0xFFu); a = (uint16_t)(a + 1u); }
        else                { jt_prog[i] = (uint8_t)(b & 0xFFu); b = (uint16_t)(b + 7u); }
    }
}

static uint16_t jt_mix(uint16_t h, uint16_t v) {
    h = (uint16_t)(h ^ v);
    h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15));
    return (uint16_t)(jt_mul(h, (uint16_t)25173u) + (uint16_t)13849u);
}

// --------------------------------------------------------------------------
// Differential gate: run the program, plot as it goes, fold everything observable.
// --------------------------------------------------------------------------
static uint16_t jt256_gate_crc(void) {
    uint16_t h = (uint16_t)0x1234u;

    jt_vm.r[0] = (uint16_t)0x0137u; jt_vm.r[1] = (uint16_t)0x7B21u;
    jt_vm.r[2] = (uint16_t)0x4E09u; jt_vm.r[3] = (uint16_t)0xC0DEu;
    jt_vm.acc  = (uint16_t)0xA5A5u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JT_MEM; i++)
        jt_vm.mem[i] = (uint8_t)((uint8_t)(i * (uint8_t)13u) ^ (uint8_t)0x3Cu);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)32u; i++) jt_seen[i] = (uint8_t)0u;
    jt_nplot = (uint16_t)0u;

    jt_program();

    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JT_STEPS; i++) {
        uint8_t op = jt_prog[i];
        jt_exec(&jt_vm, op);
        jt_seen[(uint8_t)(op >> 3)] = (uint8_t)(jt_seen[(uint8_t)(op >> 3)] |
                                                (uint8_t)((uint8_t)1u << (uint8_t)(op & 7u)));
        if (jt_nplot < (uint16_t)JT_TRACE) {
            jt_tx[jt_nplot] = (uint8_t)((jt_vm.r[0] >> 9) & 0x7Fu);
            jt_ty[jt_nplot] = (uint8_t)((jt_vm.r[1] >> 9) & 0x7Fu);
            jt_nplot++;
        }
    }

    for (uint8_t i = (uint8_t)0u; i < (uint8_t)4u; i++) h = jt_mix(h, jt_vm.r[i]);
    h = jt_mix(h, jt_vm.acc);
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)JT_MEM; i++) h = jt_mix(h, (uint16_t)jt_vm.mem[i]);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)32u; i++)      h = jt_mix(h, (uint16_t)jt_seen[i]);
    for (uint16_t i = (uint16_t)0u; i < jt_nplot; i++)
        h = jt_mix(h, (uint16_t)((uint16_t)jt_tx[i] | (uint16_t)((uint16_t)jt_ty[i] << 8)));
    return h;
}

/* Handlers actually entered, 0..256 — the visual's coverage readout, and a cross-check that
   the program really sweeps the whole opcode space (a partial sweep would weaken the test). */
static uint16_t jt256_coverage(void) {
    uint16_t n = (uint16_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)32u; i++)
        for (uint8_t b = (uint8_t)0u; b < (uint8_t)8u; b++)
            if (jt_seen[i] & (uint8_t)((uint8_t)1u << b)) n = (uint16_t)(n + 1u);
    return n;
}

#endif /* JT256_H */
