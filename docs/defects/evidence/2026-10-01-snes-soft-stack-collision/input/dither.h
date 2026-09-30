// Shared, PURE Floyd-Steinberg error-diffusion dither — host-linkable, no hardware.  Demo #70.
//
// The codegen corner: **forward-carried SIGNED error diffusion**.  Each pixel is quantised to one of 4
// levels; the SIGNED quantisation residual `e = value - quantised` is spread to the down-right neighbours
// (7/16 right, 3/16 down-left, 5/16 down, 1/16 down-right) and CLAMPED, so the next pixels see the
// accumulated signed error.  #7 (doom-fire) was decay + PRNG — a *forward-carried signed residual with a
// data-dependent quantise* is a different loop (a two-row signed error buffer threaded across a raster).
//
// Everything is integer (`int16` values + error, signed).  The residual split is `(e*k)>>4` — an
// arithmetic shift of a signed value; both the host (gcc) and llvm-mos arithmetic-shift signed right, so
// the field is bit-exact host vs target.  The quantiser is 3 compares (no divide); the level values come
// from a 4-entry LUT (no multiply).  So the FS core is pure add/shift/compare — no mul/div libcalls.
// See docs/plans/2026-06-30-70-snes-dither.md.
#ifndef DITHER_H
#define DITHER_H

#include <stdint.h>

#define DS_MAXW 64                 // max dither width (sizes the two error rows)
static const int16_t DS_LV[4] = { 0, 85, 170, 255 };   // the 4 output levels (no multiply)

// A smooth, animated source scene: two drifting diagonal ramps blended into a gradient that sweeps the
// full 0..255 range (so all four levels dither in) — smooth enough that the error diffusion produces a
// visible ordered-dither texture.  Returns 0..255.
static uint8_t ds_source(uint8_t x, uint8_t y, uint16_t t) {
    int16_t a = (int16_t)((uint16_t)(x * 11u + (t >> 1)) & 0xFFu);      // diagonal ramp 1 (drifts with t)
    int16_t b = (int16_t)((uint16_t)(y * 11u + (t >> 2)) & 0xFFu);      // diagonal ramp 2
    return (uint8_t)(((a + b) >> 1) & 0xFFu);                           // blend -> smooth 0..255 gradient
}

// Floyd-Steinberg dither a W×H frame of ds_source(.,.,t) into out[] (band indices 0..3, row-major).
// Two signed error rows with a 1-cell margin each side (index shifted +1) so x-1 / x+1 never overrun.
static void ds_dither(uint8_t W, uint8_t H, uint16_t t, uint8_t *out) {
    int16_t ecur[DS_MAXW + 2];
    int16_t enext[DS_MAXW + 2];
    for (uint16_t i = 0u; i < (uint16_t)(W + 2u); i++) ecur[i] = 0;
    for (uint8_t y = 0u; y < H; y++) {
        for (uint16_t i = 0u; i < (uint16_t)(W + 2u); i++) enext[i] = 0;
        for (uint8_t x = 0u; x < W; x++) {
            int16_t v = (int16_t)((int16_t)ds_source(x, y, t) + ecur[x + 1]);  // scene + carried error
            int16_t idx = (int16_t)(v < 43 ? 0 : (v < 128 ? 1 : (v < 213 ? 2 : 3)));  // quantise (3 cmp)
            int16_t e = (int16_t)(v - DS_LV[idx]);                            // SIGNED residual
            out[(uint16_t)y * W + x] = (uint8_t)idx;
            int16_t e7 = (int16_t)((e * 7) >> 4);     // 7/16 -> right          (arithmetic shift, signed)
            int16_t e3 = (int16_t)((e * 3) >> 4);     // 3/16 -> down-left
            int16_t e5 = (int16_t)((e * 5) >> 4);     // 5/16 -> down
            int16_t e1 = (int16_t)(e - e7 - e3 - e5); // 1/16 -> down-right (remainder: total == e exactly)
            ecur[x + 2]  = (int16_t)(ecur[x + 2]  + e7);   // right      (x+1)
            enext[x]     = (int16_t)(enext[x]     + e3);   // down-left  (x-1)
            enext[x + 1] = (int16_t)(enext[x + 1] + e5);   // down       (x)
            enext[x + 2] = (int16_t)(enext[x + 2] + e1);   // down-right (x+1)
        }
        for (uint16_t i = 0u; i < (uint16_t)(W + 2u); i++) ecur[i] = enext[i];
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t ds_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 3u                  // number of animated frames dithered into the gate
#endif
#define DS_GW 24u                  // gate grid (kept small; the FS core is O(W·H) per frame)
#define DS_GH 24u

// Fold the dithered band indices (mixed with pixel position) over GATE_N animated frames.  A miscompile
// in the signed residual, the quantiser, the clamp, or the two-row error threading changes the pattern.
static uint16_t dither_gate_crc(void) {
    static uint8_t out[DS_GW * DS_GH];
    uint16_t h = 0u;
    for (uint16_t f = 0u; f < (uint16_t)GATE_N; f++) {
        ds_dither((uint8_t)DS_GW, (uint8_t)DS_GH, (uint16_t)(f * 37u), out);
        for (uint16_t i = 0u; i < (uint16_t)(DS_GW * DS_GH); i++)
            h = ds_fold(h, (uint16_t)((uint16_t)out[i] ^ (uint16_t)(i << 2)));
    }
    return h;
}

#endif /* DITHER_H */
