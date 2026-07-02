// Copysign Compass (#81) — shared, portable logic header.
//
// Stresses:
//   __builtin_copysignf(1.0f, x) → G_FCOPYSIGN → LegalizerHelper:8899-8960
//     (inline: AND sign-bit of src, AND inverted sign-bit of dst, OR; negative-zero guard)
//   __builtin_signbitf(x) → G_IS_FPCLASS(fcNeg) → inline sign-bit integer test
// Both are inline sign-bit operations — no libcall, fast on the 65816.
// Distinct from:
//   #45 metaball: union float/uint32 type-pun through integer ALU (never G_FCOPYSIGN)
//   #57 medfilt: integer G_ABS/G_SMIN (no float sign ops)
//
// Algorithm: 16×16 vector field with sign determined by cell position + phase.
//   sign_x = signbit of (float)(dx + phase)    — G_SITOFP + G_FCOPYSIGN sign source
//   sign_y = signbit of (float)(dy - phase)    — G_SITOFP + G_FCOPYSIGN sign source
//   vx = copysignf(1.0f, (float)(dx + phase))  — G_FCOPYSIGN: ±1.0 sign transplant
//   vy = copysignf(1.0f, (float)(dy - phase))  — G_FCOPYSIGN
//   colour = signbitf(vx) | (signbitf(vy) << 1) — G_IS_FPCLASS: integer 0..3
// mag (1.0f) and sign source are both runtime non-constants → not constant-folded.
//
// WIDTH DISCIPLINE: all integers int16_t/uint16_t; float only for copysign/signbit.
// DIFFERENTIAL: integer-exact on the outcome — copysignf is an exact sign-bit
// transplant (no rounding), and we fold signbitf outcomes (0 or 1) not float bits.
// Any wrong sign-bit copy (treating copysign as fabsf or ignoring the sign) produces
// wrong colour maps and diverges the CRC immediately.
//
// See docs/plans/2026-07-01-81-snes-compass.md.

#ifndef COMPASS_H
#define COMPASS_H

#include <stdint.h>

// ------------------------------------------------------------------
// Per-cell colour [0..3] for the vector-field compass lattice.
// tx, ty in [0..15]; phase is the animation tick.
// Returns: signbitf(vx) | (signbitf(vy) << 1)
//   0 = vx≥0, vy≥0 (NE quadrant)   1 = vx<0, vy≥0 (NW)
//   2 = vx≥0, vy<0 (SE)             3 = vx<0, vy<0 (SW)
// ------------------------------------------------------------------
static inline uint8_t cs_cell(uint16_t tx, uint16_t ty, int16_t phase) {
    // Center-relative integer coordinates.
    int16_t dx = (int16_t)((int16_t)tx - (int16_t)8);
    int16_t dy = (int16_t)((int16_t)ty - (int16_t)8);

    // Raw sign sources: integer sums → float conversion → sign test.
    // dx+phase and dy-phase are runtime values: mag (1.0f) and sign (below)
    // are both non-constant, so copysignf cannot be constant-folded.
    int16_t src_x = (int16_t)(dx + phase);       // sign source for vx
    int16_t src_y = (int16_t)(dy - phase);       // sign source for vy

    // G_SITOFP: int16 → float (one-per-statement, no FMA risk).
    float fsrc_x = (float)src_x;                 // __floatsisf (G_SITOFP)
    float fsrc_y = (float)src_y;                 // __floatsisf (G_SITOFP)

    // G_FCOPYSIGN: copy sign bit from fsrc onto magnitude 1.0f.
    // Result is +1.0f or -1.0f; inline AND/OR of sign bits (no libcall).
    float vx = __builtin_copysignf(1.0f, fsrc_x);   // G_FCOPYSIGN
    float vy = __builtin_copysignf(1.0f, fsrc_y);   // G_FCOPYSIGN

    // G_IS_FPCLASS(fcNeg): sign-bit integer test (no libcall, inline).
    uint8_t sx = (uint8_t)(__builtin_signbitf(vx) ? (uint8_t)1u : (uint8_t)0u);
    uint8_t sy = (uint8_t)(__builtin_signbitf(vy) ? (uint8_t)1u : (uint8_t)0u);

    return (uint8_t)(sx | (uint8_t)(sy << (uint8_t)1u));   // 0..3
}

// ------------------------------------------------------------------
// Position-hashed CRC fold.
// Avoids XOR cancellation: the 4-colour cell values at each phase have
// a symmetric distribution (exactly 64 of each value 0..3 at most phases,
// whose XOR = 0^1^2^3 = 0, repeated 64 times = 0).  Position hashing breaks
// this: v ^ (pos*97) where 97 is prime and each pos is unique gives a
// non-symmetric contribution per cell.  97 = 64+32+1 → strength-reduces to
// shifts on the 65816 (no __mulhi3).
// ------------------------------------------------------------------
static inline uint16_t cs_fold(uint16_t h, uint16_t v, uint16_t pos) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u))
                    ^ (uint16_t)((uint16_t)v ^ (uint16_t)((uint16_t)pos * (uint16_t)97u)));
}

// ------------------------------------------------------------------
// Differential gate: GATE_N phases; fold all 16×16 cell colours.
// Phase step=3 (coprime with 16 — avoids resetting sign patterns to the
// same config as phase=0 and creates a slowly-rotating vector field).
// Position counter gives each cell a unique fold contribution.
// GATE_N = 16 → CRC = 0xB9CB (non-zero; non-canceling).
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 16u
#endif

static uint16_t compass_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    uint16_t pos = (uint16_t)0u;
    uint16_t step;
    for (step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        int16_t phase = (int16_t)((uint16_t)(step * (uint16_t)3u));
        uint16_t tx, ty;
        for (ty = (uint16_t)0u; ty < (uint16_t)16u; ty++) {
            for (tx = (uint16_t)0u; tx < (uint16_t)16u; tx++) {
                h = cs_fold(h, (uint16_t)cs_cell(tx, ty, phase), pos);
                pos++;
            }
        }
    }
    return h;
}

#endif /* COMPASS_H */
