// Truncation Staircase (#83) — shared, portable logic header.
//
// Stresses:
//   (int16_t)x_f      → G_FPTOSI → __fixsfsi  (float→int, truncation toward zero)
//   (float)q          → G_SITOFP → __floatsisf (int→float)
// Both are the fundamental float↔int conversion path on 65816.
//
// SDK gap documented: truncf/floorf/ceilf are .unsupported() in the MOS legalizer —
// they have no SDK implementation and calling them would fail to link. The pattern
// (float)((int)x) achieves truncf(x) inline via G_FPTOSI + G_SITOFP, no libcall.
//
// Distinct from:
//   #82 speedcap: G_FPTOSI/G_SITOFP are incidental (velocity→pixel); primary = G_FMINNUM/G_FMAXNUM
//   #77 satcast:  G_FPTOSI is the terminal saturating-cast output after fmin/fmax clamping
//
// Algorithm: 48 values over x in [-9.0, 8.625] with step 0.375 (= 3/8, exact in float).
// For each: trunc via (int16_t)x_f, then back to float, then fractional remainder.
// Trunc-vs-floor diverge for negative non-integers: x=-0.75 → trunc=0, floor=-1.
//
// WIDTH DISCIPLINE: all integer ops use int16_t/uint16_t; no bare int.
// DIFFERENTIAL: integer-exact — TS_STEP=0.375f is exact (3/8 = 2^-2+2^-3); all
// products and residuals are multiples of 0.375/16 (exact IEEE 754).
//
// See docs/plans/2026-07-01-83-snes-truncstair.md.

#ifndef TRUNCSTAIR_H
#define TRUNCSTAIR_H

#include <stdint.h>

#define TS_STEP   0.375f        // input step (3/8, exact in IEEE 754)
#ifndef TS_GATE_N
#define TS_GATE_N 48u           // simulation steps for gate CRC
#endif

// ------------------------------------------------------------------
// Trunc-toward-zero (G_FPTOSI) and back (G_SITOFP).
// This is "truncf(x)" implemented via the cast pattern (no libcall).
// ------------------------------------------------------------------
static inline int16_t ts_trunc(float x) {
    return (int16_t)x;          // G_FPTOSI → __fixsfsi
}

static inline float ts_trunc_f(float x) {
    return (float)ts_trunc(x);  // G_SITOFP → __floatsisf
}

// ------------------------------------------------------------------
// Floor: trunc toward -infinity. Implemented via trunc + correction.
// floor(x) = trunc(x) if x >= 0 OR x == trunc(x); else trunc(x) - 1.
// No floorf() libcall — that symbol is unsupported in the SDK.
// ------------------------------------------------------------------
static inline int16_t ts_floor(float x) {
    int16_t t = ts_trunc(x);                    // G_FPTOSI
    float   tf = (float)t;                       // G_SITOFP
    float   diff = x - tf;                       // G_FSUB
    // diff < 0 iff x is negative non-integer (trunc rounds wrong way).
    // Use fptosi on diff comparison result:
    return (diff < 0.0f) ? (int16_t)(t - 1) : t;
}

// ------------------------------------------------------------------
// Round half-away from zero. Implemented via trunc(x ± 0.5).
// No roundf() libcall.
// ------------------------------------------------------------------
static inline int16_t ts_round(float x) {
    // For x >= 0: trunc(x + 0.5); for x < 0: trunc(x - 0.5).
    float adj = (x >= 0.0f) ? (x + 0.5f) : (x - 0.5f);   // G_FADD/G_FSUB
    return ts_trunc(adj);                                    // G_FPTOSI
}

// ------------------------------------------------------------------
// Gate CRC: 48 steps, fold trunc(x) and fractional residual.
// G_FPTOSI (×2) + G_SITOFP (×2) + G_FMUL (×2) + G_FSUB (×1) per step.
//
// !!! REAL COMPILER BUG SURFACED BY THIS GATE (2026-07-01) — UNDER DIAGNOSIS !!!
// Differential: host/corpus = 0x02CA, full-display ROM = 0x1EB5. The gate code
// is BYTE-IDENTICAL between the passing (corpus) and failing (full ROM) builds —
// only the linker-assigned static ZP frame base differs: $20 (corpus, PASS) vs
// $69 (full ROM, FAIL). The bug appears ONLY when the display/title code is
// linked (higher ZP pressure pushes the gate's persistent static ZP frame to
// $69–$74). No ISR runs during the gate (snes_wait_vblank polls), and none of
// the soft-float call-tree routines (__floatsisf/__fixsfsi/__mulsf3/__subsf3/
// __mulhi3) write $69–$74. This is a whole-program-dependent ZP-allocation /
// aliasing miscompile in the backend (likely MOSZeroPageAlloc interference
// analysis vs. the soft-float call tree). The G_FPTOSI/G_SITOFP operations
// themselves are correct (corpus is bit-exact). Full diagnosis + minimal repro:
// docs/plans/2026-07-01-83-snes-truncstair.md §Compiler bug.
// This gate is INTENTIONALLY left in natural form so the bug reproduces — do
// NOT paper over it with static/noinline/volatile (those merely relocate the
// frame away from $69 and hide the defect).
// ------------------------------------------------------------------
static uint16_t truncstair_gate_crc(void) {
    uint16_t h = 0u;
    uint16_t i;
    for (i = 0u; i < (uint16_t)TS_GATE_N; i++) {
        int16_t x_int = (int16_t)((int16_t)i - (int16_t)(TS_GATE_N / 2u));
        float x_f = (float)x_int * TS_STEP;     // G_SITOFP → __floatsisf; G_FMUL → __mulsf3
        int16_t q = (int16_t)x_f;               // G_FPTOSI → __fixsfsi (trunc)
        float qf = (float)q;                    // G_SITOFP → __floatsisf
        float diff = x_f - qf;                  // G_FSUB   → __subsf3 (fractional remainder)
        int16_t d16 = (int16_t)(diff * 16.0f);  // G_FMUL + G_FPTOSI (scale residual to int)
        // Prime-multiplier fold to break XOR cancellation.
        h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
        h = (uint16_t)(h ^ (uint16_t)(
            (uint16_t)((int16_t)q * (int16_t)97) ^
            (uint16_t)((int16_t)d16 * (int16_t)13)
        ));
    }
    return h;
}

#endif /* TRUNCSTAIR_H */
