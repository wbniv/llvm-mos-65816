// Borrow-Ladder Odometer (#110) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster E. Re-stresses patch 0012 (`LDCImm`-set): the backend lowers a
// **set i1 carry** (the carry-in that must be SET — `SEC` — before the first `SBC` of a subtract
// chain) via a materialized `LDCImm 1`. A wide multi-precision subtractor built from chained 16-bit
// subtracts-with-borrow is exactly that shape: the borrow ripples limb to limb, and every limb's
// subtract consumes a carry-in that is a set/clear i1. This runs a 128-bit descending odometer that
// ticks DOWN (through zero, wrapping) by subtracting a decrement each step, borrows rippling across
// eight 16-bit limbs. The a16/xy16 legs are load-bearing (0012 is accum-gated); default 8-bit is the
// contrast.
//
// DIFFERENTIAL: multi-precision subtraction is exact → bit-identical host vs target. A wrong set-i1
// carry materialization (a dropped/duplicated borrow) diverges the running value's CRC. WIDTH
// DISCIPLINE: explicit uint16/int32; no bare int; no float. See the plan.

#ifndef BORROWLAD_H
#define BORROWLAD_H

#include <stdint.h>

#define BL_LIMBS 8u          // 8 × 16-bit = 128-bit odometer, little-endian
typedef struct { uint16_t w[BL_LIMBS]; } U128;

// a -= b, 16-bit borrow chain across all limbs. Each limb subtract consumes a borrow-in (a set/clear
// i1) — the LDCImm-set shape 0012 lowers. noinline to hold the borrow chain in one function.
__attribute__((noinline))
static void bl_sub(U128 *a, const U128 *b) {
    uint16_t borrow = (uint16_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BL_LIMBS; i++) {
        int32_t t = (int32_t)a->w[i] - (int32_t)b->w[i] - (int32_t)borrow;   // 16-bit sub with borrow-in
        a->w[i] = (uint16_t)t;
        borrow = (uint16_t)((t < (int32_t)0) ? 1u : 0u);                     // borrow-out (a set i1)
    }
}

static inline uint16_t bl_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ v);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: a 128-bit odometer counts DOWN by a decrement each step (borrows ripple),
// wrapping through zero; fold all eight limbs every step.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 160u
#endif

static uint16_t borrowlad_gate_crc(void) {
    U128 odo, dec;
    // start near the top of the 128-bit range so the countdown ripples borrows through every limb.
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)BL_LIMBS; i++) odo.w[i] = (uint16_t)0xFFFFu;
    odo.w[0] = (uint16_t)0x0003u;                    // low limb small → immediate borrow cascade
    // decrement spread across limbs so borrows propagate far each subtract.
    dec.w[0] = (uint16_t)0x9E37u; dec.w[1] = (uint16_t)0x79B9u;
    dec.w[2] = (uint16_t)0x7F4Au; dec.w[3] = (uint16_t)0x7C15u;
    dec.w[4] = (uint16_t)0xF39Cu; dec.w[5] = (uint16_t)0xC060u;
    dec.w[6] = (uint16_t)0x5CEDu; dec.w[7] = (uint16_t)0xC834u;

    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        bl_sub(&odo, &dec);
        for (uint8_t i = (uint8_t)0u; i < (uint8_t)BL_LIMBS; i++) h = bl_fold(h, odo.w[i]);
    }
    return h;
}

#define BL_WIN 16u

#endif /* BORROWLAD_H */
