// DCT Bloom (#88) — shared, portable logic header.
//
// Stresses: 8x8 separable integer DCT — int32 multiply-accumulate (16x16->32 via __mulsi3)
// followed by a SIGNED arithmetic-shift-right descale and a narrowing cast back to int16
// (G_ASHR + G_SEXT_INREG). Each output coefficient is sum(M[u][x] * block[x]) in int32,
// then >> SHIFT (signed) and narrowed. Distinct from #25 fft (radix-2 butterflies, twiddle
// LUT, complex pairs) — this is a dense O(N^2) cosine MAC with signed descale/narrow.
//
// WIDTH DISCIPLINE: int16_t samples/coeffs, int32_t accumulators. No bare int.
// DIFFERENTIAL: exact integer DCT — bit-identical host vs 65816. Any wrong 16x16->32 MAC,
// or a signed >> that shifts in the wrong sign bit, or a bad narrowing cast, diverges the fold.
//
// See docs/plans/2026-07-01-88-snes-dctbloom.md.

#ifndef DCTBLOOM_H
#define DCTBLOOM_H

#include <stdint.h>

#define DB_SHIFT 8u                 // Q8 matrix; descale each 1D pass by >>8 (signed)
#ifndef DB_GATE_N
#define DB_GATE_N 4u                // phases folded into the gate
#endif

// Q8 8x8 DCT-II basis matrix (precomputed, scale 256).
static const int16_t DCT_M[8][8] = {
  {  91,   91,   91,   91,   91,   91,   91,   91},
  { 126,  106,   71,   25,  -25,  -71, -106, -126},
  { 118,   49,  -49, -118, -118,  -49,   49,  118},
  { 106,  -25, -126,  -71,   71,  126,   25, -106},
  {  91,  -91,  -91,   91,   91,  -91,  -91,   91},
  {  71, -126,   25,  106, -106,  -25,  126,  -71},
  {  49, -118,  118,  -49,  -49,  118, -118,   49},
  {  25,  -71,  106, -126,  126, -106,   71,  -25},
};

// Procedural 8x8 source block (signed, ~[-128,127]), animated by phase.
static inline int16_t db_src(uint8_t x, uint8_t y, int16_t phase) {
    int16_t a = (int16_t)(((int16_t)(x * 40) + phase) & 255);
    int16_t b = (int16_t)(((int16_t)(y * 24) - phase) & 255);
    // two ramps + a checker → a mix of low and high frequencies
    int16_t v = (int16_t)((a - 128) + (b - 128));
    if (((x ^ y) & 1) != 0) v = (int16_t)(v + 40);
    if (v > 127) v = 127; if (v < -128) v = -128;
    return v;
}

// One 1D 8-point DCT of a row `in[8]` -> `out[8]`; int32 MAC then signed descale+narrow.
static inline void db_dct8(const int16_t *in, int16_t *out) {
    uint8_t u, x;
    for (u = 0u; u < 8u; u++) {
        int32_t acc = 0;                                       // int32 accumulator
        for (x = 0u; x < 8u; x++)
            acc += (int32_t)((int32_t)DCT_M[u][x] * (int32_t)in[x]);   // 16x16->32 __mulsi3 MAC
        int32_t d = (int32_t)(acc >> DB_SHIFT);                // SIGNED arithmetic shift (G_ASHR)
        out[u] = (int16_t)d;                                   // narrowing cast (G_SEXT_INREG on reload)
    }
}

// Full separable 8x8 DCT of the source block at `phase` → coeff[8][8].
static inline void db_dct8x8(int16_t phase, int16_t coeff[8][8]) {
    int16_t tmp[8][8];
    int16_t row[8], orow[8];
    uint8_t y, x, u;
    // rows
    for (y = 0u; y < 8u; y++) {
        for (x = 0u; x < 8u; x++) row[x] = db_src(x, y, phase);
        db_dct8(row, orow);
        for (u = 0u; u < 8u; u++) tmp[y][u] = orow[u];
    }
    // columns
    for (x = 0u; x < 8u; x++) {
        for (y = 0u; y < 8u; y++) row[y] = tmp[y][x];
        db_dct8(row, orow);
        for (u = 0u; u < 8u; u++) coeff[u][x] = orow[u];
    }
}

// ------------------------------------------------------------------
// Gate CRC: DCT the block at GATE_N phases, fold every coefficient.
// ------------------------------------------------------------------
static uint16_t dctbloom_gate_crc(void) {
    uint16_t h = 0u;
    int16_t phase;
    for (phase = 0; phase < (int16_t)((int16_t)DB_GATE_N * 16); phase = (int16_t)(phase + 16)) {
        int16_t coeff[8][8];
        db_dct8x8(phase, coeff);
        uint8_t u, x;
        for (u = 0u; u < 8u; u++)
            for (x = 0u; x < 8u; x++) {
                h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
                h = (uint16_t)(h ^ (uint16_t)((int16_t)coeff[u][x] * (int16_t)97));
            }
    }
    return h;
}

#endif /* DCTBLOOM_H */
