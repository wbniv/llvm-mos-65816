// Shared, PURE complex domain-colouring with poles — host-linkable, no hardware.  Demo #58.
//
// The codegen corner: **NaN / unordered floating-point compares**.  A rational complex function
// f(z) = (z^2 - 1) / (z^2 + c) has poles where z^2 + c == 0; the divide there produces +/-Inf or NaN, and
// the colouring branches on isnan / isinf to paint the singularities.  Those tests are:
//   isnan(x)  ==  (x != x)   -> __unordsf2 (unordered compare) / __nesf2
//   x == y                    -> __eqsf2
// #21/#33 only ever used the ORDERED `<` (escape test); equality and unordered/NaN compares are a
// different libcall set that nothing in the first 57 demos emits.
//
// DIFFERENTIAL SAFETY (critical): a quiet-NaN payload is not fully specified, so we NEVER fold raw float
// bits.  We fold only the **colour index** — the branch OUTCOME (isnan -> which colour) — which is a
// deterministic boolean identical on host and target (NaN is NaN; Inf compares the same).  The finite
// phase colour comes from sign/magnitude COMPARES only (no atan2/transcendental -> no libm ULP issue).
// Single-precision float is bit-identical host==target IF FMA is forbidden, so every arithmetic op is on
// its OWN statement (one op per line) per [[softfloat-bit-exact-differential]].
// See docs/plans/2026-06-30-58-snes-domcol.md.
#ifndef DOMCOL_H
#define DOMCOL_H

#include <stdint.h>

// isnan without <math.h>: only NaN is unequal to itself -> __unordsf2 / __nesf2.
static inline uint8_t domcol_isnan(float x) { return (uint8_t)(x != x); }

// isinf without <math.h>: compare |x| to a huge finite threshold; a true Inf exceeds any finite value.
// (x - x) is 0 for finite x but NaN for +/-Inf, so (x==x && (x>BIG || x<-BIG)) flags Inf, not NaN.
static inline uint8_t domcol_isbig(float x) {
    uint8_t ordered = (uint8_t)(x == x);          // __eqsf2: false for NaN
    uint8_t hi = (uint8_t)(x > 1.0e18f);          // __gtsf2
    uint8_t lo = (uint8_t)(x < -1.0e18f);         // __ltsf2
    return (uint8_t)(ordered && (hi || lo));
}

// Colour a grid cell (gx,gy) in [0,16) for the rational map with parameter (cr,ci).  Returns 0..3.
// One arithmetic op per statement (no FMA) so the soft-float result is bit-identical host vs target.
static uint8_t domcol_cell(uint8_t gx, uint8_t gy, float cr, float ci) {
    // map the cell to z in roughly [-2,2] x [-2,2]
    float zr = (float)((int16_t)gx - 8);
    zr = zr * 0.25f;
    float zi = (float)((int16_t)gy - 8);
    zi = zi * 0.25f;

    // z^2  (complex): re = zr*zr - zi*zi ; im = 2*zr*zi   — one op per line
    float zr2 = zr * zr;
    float zi2 = zi * zi;
    float re2 = zr2 - zi2;
    float cross = zr * zi;
    float im2 = cross + cross;

    // numerator z^2 - 1 ; denominator z^2 + c
    float nr = re2 - 1.0f;
    float ni = im2;
    float dr = re2 + cr;
    float di = im2 + ci;

    // complex divide f = num * conj(den) / |den|^2  — |den|^2 can be 0 -> Inf/NaN
    float dr2 = dr * dr;
    float di2 = di * di;
    float dd = dr2 + di2;
    float p1 = nr * dr;
    float p2 = ni * di;
    float rn = p1 + p2;
    float p3 = ni * dr;
    float p4 = nr * di;
    float in = p3 - p4;
    float inv = 1.0f / dd;      // ONE reciprocal (soft-float divide is costly); 1/0 = Inf at a pole
    float fr = rn * inv;        // rn*Inf -> Inf, or 0*Inf -> NaN at an exact pole (the interesting path)
    float fi = in * inv;

    // pole detection: 0/0 at an exact pole -> NaN -> the unordered-compare corner (__unordsf2/__nesf2).
    uint8_t nan_r = domcol_isnan(fr);
    uint8_t nan_i = domcol_isnan(fi);
    if (nan_r || nan_i) return 3u;                             // white pole (NaN)
    // Inf guard: a true +/-Inf (x/0 with x!=0) also reads as the pole colour (uses __eqsf2 via isbig).
    if (domcol_isbig(fr) || domcol_isbig(fi)) return 3u;
    // finite: concentric domain-colouring bands by magnitude |fr|+|fi| via ORDERED compares.
    float afr = (fr < 0.0f) ? -fr : fr;                        // float abs (sign flip, no libcall)
    float afi = (fi < 0.0f) ? -fi : fi;
    float mag = afr + afi;
    if (mag > 8.0f) return 2u;                                 // near-pole halo (bright)
    if (mag > 1.5f) return 1u;                                 // mid band
    return 0u;                                                 // far / background
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t domcol_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 4u           // soft-float is very costly (~150k cyc/cell even with one reciprocal);
#endif                      // keep the gate tiny so corpus_result is set well before frame 500

// Fold the COLOUR INDEX (branch outcome) over a few c-parameters, sampling a row through the grid centre
// plus an EXPLICIT exact-pole evaluation each iteration (c=0 puts a pole at z=0, cell (8,8) -> dd==0 ->
// NaN), so the __unordsf2/isnan corner is always covered even with few cells.  Soft-float is slow, so the
// cell count is small.  A miscompile in the NaN/unordered compares or the finite arithmetic changes a
// colour -> divergence; raw NaN bits are never hashed.
static uint16_t domcol_gate_crc(void) {
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        float cr = (float)((int16_t)(i & 3u) - 2);
        cr = cr * 0.25f;
        float ci = (float)((int16_t)((i >> 1) & 3u) - 1);
        ci = ci * 0.25f;
        for (uint8_t k = 0u; k < 9u; k++) {
            uint8_t gx = (uint8_t)(4u + k);          // a row through the centre (gy=8) crossing gx=8
            uint8_t col = domcol_cell(gx, 8u, cr, ci);
            h = domcol_fold(h, (uint16_t)col);
        }
        h = domcol_fold(h, (uint16_t)domcol_cell(8u, 8u, 0.0f, 0.0f));   // guaranteed NaN pole
    }
    return h;
}

#endif /* DOMCOL_H */
