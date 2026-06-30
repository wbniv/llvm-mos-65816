// Times-table cardioid — the shared, portable math for demo #27.
//
// The hot loop:  j = (k * i) % N  where k is the multiplier and i is the point index.
// Explicit uint32_t casts force 32-bit libcalls (__mulsi3 + __umodsi3) even though k*i
// fits in 16 bits, because k<=30 and i<=199 → k*i<=5970.  This is the codegen corner
// no other demo in the battery exercises: __umodsi3 (remainder-only) as the sole hot op.
//
// No hardware / no snes.h — host-linkable.  The circle point precomputation is done
// in the SNES ROM (cardioid.c) using the SPIRO_SIN_LUT; this header only provides the
// gate CRC and the constants so the corpus slice and host oracle stay dependency-free.
//
// Gate:  card_gate_crc() — k=2..8 × i=0..199, folds (uint32_t)k*(uint32_t)i%(uint32_t)N.
// Total: 7 × 200 = 1 400 inner iterations.
//
// NO bare int — every width is explicit (uint16_t / uint32_t).  See CLAUDE.md §width rules.
#ifndef CARDIOID_H
#define CARDIOID_H

#include <stdint.h>

#define CARD_N    200u   /* evenly-spaced circle points */
#define CARD_KMIN   2u   /* first multiplier (k=2 → cardioid) */
#define CARD_KMAX  30u   /* last multiplier */
#define CARD_R     56    /* circle radius in pixels on the 128×128 canvas */
#define CARD_CX    64    /* canvas centre X */
#define CARD_CY    64    /* canvas centre Y */

/* Gate CRC — pure function, no state.
   Folds k * (i + 65536) % CARD_N into a rotate-XOR hash.
   The +65536 offset makes the second factor exceed UINT16_MAX for all i, which prevents
   LLVM from narrowing the 32-bit multiply to a 16-bit one (the compiler correctly sees that
   k*i ≤ 8*199 = 1592 fits in uint16, so (uint32_t)k*(uint32_t)i is widened back down).
   With i+65536 ≥ 65536 > UINT16_MAX, the product k*(i+65536) ≥ 65536 → genuinely 32-bit
   → __mulsi3 + __umodsi3 (not the 16-bit __umodhi3 variants). */
static inline uint16_t card_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t k = CARD_KMIN; k <= 8u; k++) {
        for (uint16_t i = 0; i < (uint16_t)CARD_N; i++) {
            uint32_t j = (uint32_t)k * ((uint32_t)i + 65536u) % (uint32_t)CARD_N;
            h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)j;
        }
    }
    return h;
}

#endif /* CARDIOID_H */
