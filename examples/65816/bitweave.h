// Serial Bit-Reversal Weave (#107) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster D. Re-stresses patch 0010 (coalesce-rotate-Ac): a DEFAULT-
// 8-BIT (NOT accum-gated) register-coalescer miscompile that stranded a loop-carried byte while a
// back-edge rotate read a stale accumulator. This does a bit reversal the HARD way — a serial
// **rotate-out / rotate-in** carry loop: each iteration shifts one bit OUT of the source (`v >>= 1`,
// the low bit into "carry") and rotates it INTO the destination (`rev = (rev << 1) | bit`). The
// `rev` register is loop-carried and rotated on the back edge — the exact 0010 shape. This is a
// deliberate CONTRAST to #54 bitshuffle, which used `__builtin_bitreverse32` → the `G_BITREVERSE`
// mask-swap cascade (no loop, no loop-carried rotate). Two reversals (an 8-bit and a 16-bit) run
// interleaved in one loop so two loop-carried `rev` registers are live at once (extra pressure).
//
// This bug is 8-bit-only, so the DEFAULT build is the load-bearing leg. DIFFERENTIAL: bit reversal
// is a pure permutation of bits → bit-identical host vs target, and an INVOLUTION (rev(rev(v))==v),
// a built-in self-check. A coalescer strand corrupts a loop-carried `rev` → the folded stream
// diverges (default 8-bit). WIDTH DISCIPLINE: explicit uint8/uint16; no bare int; no float; NO
// bit-reverse intrinsic. See the plan.

#ifndef BITWEAVE_H
#define BITWEAVE_H

#include <stdint.h>

// Serial 8-bit reversal — loop-carried `rev`, rotate-out of `v` + rotate-in to `rev`.
static inline uint8_t bw_rev8(uint8_t v) {
    uint8_t rev = (uint8_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)8u; i++) {
        rev = (uint8_t)((uint8_t)(rev << 1) | (uint8_t)(v & (uint8_t)1u));   // rotate the low bit in
        v = (uint8_t)(v >> 1);                                                // rotate the source out
    }
    return rev;
}

// Serial 16-bit reversal — a wider loop-carried strand.
static inline uint16_t bw_rev16(uint16_t v) {
    uint16_t rev = (uint16_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)16u; i++) {
        rev = (uint16_t)((uint16_t)(rev << 1) | (uint16_t)(v & (uint16_t)1u));
        v = (uint16_t)(v >> 1);
    }
    return rev;
}

// Interleaved weave: reverse an 8-bit AND a 16-bit value in ONE loop, so both loop-carried `rev`
// registers (r8, r16) are live and rotated on every back edge (maximal coalescer pressure).
__attribute__((noinline))
static void bw_weave(uint8_t *a8, uint16_t *a16) {
    uint8_t  v8 = *a8,   r8 = (uint8_t)0u;
    uint16_t v16 = *a16, r16 = (uint16_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)16u; i++) {
        if (i < (uint8_t)8u) {
            r8 = (uint8_t)((uint8_t)(r8 << 1) | (uint8_t)(v8 & (uint8_t)1u));
            v8 = (uint8_t)(v8 >> 1);
        }
        r16 = (uint16_t)((uint16_t)(r16 << 1) | (uint16_t)(v16 & (uint16_t)1u));
        v16 = (uint16_t)(v16 >> 1);
    }
    *a8 = r8; *a16 = r16;
}

static inline uint16_t bw_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ v);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: weave a deterministic stream; fold both reversed words AND the involution
// witness (bw_weave twice must restore the original → XOR-in a 0 when correct).
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 128u
#endif

static uint16_t bitweave_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    uint16_t seed = (uint16_t)0xACE1u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        seed = (uint16_t)(seed * 25173u + 13849u);          // deterministic LCG
        uint8_t  a8  = (uint8_t)(seed >> 5);
        uint16_t a16 = seed;
        uint8_t  o8  = a8;
        uint16_t o16 = a16;
        bw_weave(&a8, &a16);                                 // reverse
        h = bw_fold(h, (uint16_t)a8);
        h = bw_fold(h, a16);
        bw_weave(&a8, &a16);                                 // reverse again → must restore
        h = bw_fold(h, (uint16_t)((uint16_t)(a8 ^ o8)));     // involution witness: 0 when correct
        h = bw_fold(h, (uint16_t)(a16 ^ o16));               // involution witness: 0 when correct
    }
    return h;
}

#endif /* BITWEAVE_H */
