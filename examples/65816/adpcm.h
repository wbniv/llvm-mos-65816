// ADPCM Waverider (#89) — shared, portable logic header.
//
// Stresses: G_SADDSAT/G_SSUBSAT (via __builtin_elementwise_add_sat/_sub_sat) inside a
// SERIAL FEEDBACK loop — an IMA-ADPCM decoder whose predictor is clamped with saturating
// add/sub each sample, and whose step-size walks a LUT indexed by a running state. Each
// output depends on the previous predictor (true recurrence, not parallelizable). Distinct
// from #48 IIR (wrapping fixed-point feedback, no saturation) and #67 huffman (no feedback).
//
// WIDTH DISCIPLINE: int16_t predictor/samples, int32_t diff accum. No bare int.
// DIFFERENTIAL: exact integer ADPCM — bit-identical host vs 65816. A saturating add that
// wraps, or a wrong step-index walk, diverges the whole waveform after that sample (feedback).
//
// See docs/plans/2026-07-01-89-snes-adpcm.md.

#ifndef ADPCM_H
#define ADPCM_H

#include <stdint.h>

#ifndef AD_GATE_N
#define AD_GATE_N 400u          // nibbles decoded in the gate
#endif

// IMA-ADPCM step-size table (89 entries) and index-adjust table (16 entries).
static const int16_t AD_STEP[89] = {
    7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,
    118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,
    963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,
    5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,
    24623,27086,29794,32767
};
static const int16_t AD_IDX[16] = { -1,-1,-1,-1,2,4,6,8, -1,-1,-1,-1,2,4,6,8 };

typedef struct { int16_t pred; int16_t idx; } AdpcmState;

static inline void ad_init(AdpcmState *s) { s->pred = 0; s->idx = 0; }

#if defined(__clang__)
static inline int16_t ad_add_sat(int16_t a, int16_t b) { return __builtin_elementwise_add_sat(a, b); }
static inline int16_t ad_sub_sat(int16_t a, int16_t b) { return __builtin_elementwise_sub_sat(a, b); }
#else
static inline int16_t ad_add_sat(int16_t a, int16_t b) {
    int32_t r = (int32_t)a + (int32_t)b; if (r > 32767) r = 32767; if (r < -32768) r = -32768; return (int16_t)r;
}
static inline int16_t ad_sub_sat(int16_t a, int16_t b) {
    int32_t r = (int32_t)a - (int32_t)b; if (r > 32767) r = 32767; if (r < -32768) r = -32768; return (int16_t)r;
}
#endif

// Decode one 4-bit nibble → next predictor sample (serial feedback).
static inline int16_t ad_decode(AdpcmState *s, uint8_t nib) {
    int16_t step = AD_STEP[s->idx];
    int32_t diff = (int32_t)(step >> 3);
    if (nib & 4u) diff += step;
    if (nib & 2u) diff += (step >> 1);
    if (nib & 1u) diff += (step >> 2);
    int16_t d = (int16_t)diff;                        // diff < 4*32767 fits after the >>? clamp below
    if (d < 0) d = 32767;                              // guard (diff can exceed int16 for large step)
    // saturating predictor update — G_SADDSAT / G_SSUBSAT
    if (nib & 8u) s->pred = ad_sub_sat(s->pred, d);
    else          s->pred = ad_add_sat(s->pred, d);
    // step-index walk (LUT), clamped to [0,88]
    s->idx = (int16_t)(s->idx + AD_IDX[nib & 15u]);
    if (s->idx < 0) s->idx = 0;
    if (s->idx > 88) s->idx = 88;
    return s->pred;
}

static inline uint16_t ad_xs16(uint16_t x) { x^=(uint16_t)(x<<7); x^=(uint16_t)(x>>9); x^=(uint16_t)(x<<8); return x; }

// ------------------------------------------------------------------
// Gate CRC: decode AD_GATE_N PRNG nibbles, fold the predictor stream.
// ------------------------------------------------------------------
static uint16_t adpcm_gate_crc(void) {
    AdpcmState s; ad_init(&s);
    uint16_t r = 0xC0DEu;
    uint16_t h = 0u;
    uint16_t i;
    for (i = 0u; i < (uint16_t)AD_GATE_N; i++) {
        r = ad_xs16(r);
        uint8_t nib = (uint8_t)((r >> (uint16_t)((i & 3u) * 4u)) & 15u);
        int16_t sample = ad_decode(&s, nib);
        h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
        h = (uint16_t)(h ^ (uint16_t)sample);
    }
    return h;
}

#endif /* ADPCM_H */
