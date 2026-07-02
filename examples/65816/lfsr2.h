// Dual-LFSR Scrambler (#106) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster D. Re-stresses patch 0010 (coalesce-rotate-Ac): a DEFAULT-
// 8-BIT (NOT accum-gated) register-coalescer miscompile where two shift/rotate-referenced values
// were merged into the A-only `Ac` class, stranding a loop-carried byte while the back-edge `ROL`
// read a stale A. #105 crcwall re-stressed it with three bit-serial CRCs; this uses TWO different
// LFSR feedback structures live at once — a maximal-length **Galois** LFSR (shift + conditional
// tap-XOR: the shifted-out bit gates a poly XOR, a rotate-into-carry shape) and a **Fibonacci** LFSR
// (XOR-of-taps fed back into the top bit: a rotate-in shape) — each a loop-carried 8-bit register
// with a back-edge rotate, stepped SIMULTANEOUSLY so both registers + both feedbacks are live at
// once (extra coalescer pressure). A 16-bit Galois pair adds a wider loop-carried strand.
//
// This bug is 8-bit-only, so the DEFAULT build is the load-bearing leg (invisible to every
// +mos-a16/+mos-xy16 gate). DIFFERENTIAL: an LFSR is pure shift/xor → bit-identical host vs target;
// a coalescer strand corrupts a loop-carried register and the folded stream diverges (default 8-bit).
// WIDTH DISCIPLINE: explicit uint8/uint16; no bare int; no float. See the plan.

#ifndef LFSR2_H
#define LFSR2_H

#include <stdint.h>

#define LF_GAL8   ((uint8_t)0xB8u)     // Galois 8-bit tap mask (maximal length, period 255)
#define LF_GAL16  ((uint16_t)0xB400u)  // Galois 16-bit tap mask (x^16+x^14+x^13+x^11+1, period 65535)

typedef struct { uint8_t g8; uint8_t f8; uint16_t g16; } Lfsr2State;

// One combined step: advance the Galois-8, Fibonacci-8 AND Galois-16 LFSRs, all loop-carried,
// stepped together so their registers + feedbacks are simultaneously live (the 0010 pressure).
__attribute__((noinline))
static void lf_step(Lfsr2State *s) {
    // Galois-8: shift right; if the bit shifted OUT (bit 0) is 1, XOR the tap mask. Rotate-into-carry.
    uint8_t g8_out = (uint8_t)(s->g8 & (uint8_t)1u);
    s->g8 = (uint8_t)(s->g8 >> 1);
    if (g8_out != (uint8_t)0u) s->g8 = (uint8_t)(s->g8 ^ LF_GAL8);

    // Fibonacci-8: feedback = XOR of taps (bits 0,2,3,4), shift right, insert feedback at bit 7.
    uint8_t f8_fb = (uint8_t)((uint8_t)((s->f8 >> 0) ^ (s->f8 >> 2) ^ (s->f8 >> 3) ^ (s->f8 >> 4)) & (uint8_t)1u);
    s->f8 = (uint8_t)((uint8_t)(s->f8 >> 1) | (uint8_t)(f8_fb << 7));

    // Galois-16: same structure at 16-bit (a wider loop-carried strand under the same pressure).
    uint16_t g16_out = (uint16_t)(s->g16 & (uint16_t)1u);
    s->g16 = (uint16_t)(s->g16 >> 1);
    if (g16_out != (uint16_t)0u) s->g16 = (uint16_t)(s->g16 ^ LF_GAL16);
}

// Single Galois-8 step for the display (loop-carried 8-bit shift register, default-8-bit).
static inline uint8_t lf_gal8_next(uint8_t v) {
    uint8_t out = (uint8_t)(v & (uint8_t)1u);
    v = (uint8_t)(v >> 1);
    return (uint8_t)(out ? (uint8_t)(v ^ LF_GAL8) : v);
}
static inline uint8_t lf_fib8_next(uint8_t v) {
    uint8_t fb = (uint8_t)((uint8_t)((v >> 0) ^ (v >> 2) ^ (v >> 3) ^ (v >> 4)) & (uint8_t)1u);
    return (uint8_t)((uint8_t)(v >> 1) | (uint8_t)(fb << 7));
}

static inline uint16_t lf_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ v);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: step both 8-bit LFSRs + the 16-bit one GATE_N times, folding all three states.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 200u
#endif

static uint16_t lfsr2_gate_crc(void) {
    Lfsr2State s;
    s.g8 = (uint8_t)0xACu; s.f8 = (uint8_t)0x1Du; s.g16 = (uint16_t)0xBEEFu;
    uint16_t h = (uint16_t)0u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        lf_step(&s);
        h = lf_fold(h, (uint16_t)s.g8);
        h = lf_fold(h, (uint16_t)s.f8);
        h = lf_fold(h, s.g16);
    }
    return h;
}

// -------- ROM display: two interleaved pseudo-noise fields -------------------------------------
#define LF_GRID 16u

#endif /* LFSR2_H */
