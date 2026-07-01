// Shared, PURE powers-of-ten "cosmic zoom" ruler — host-linkable, no hardware.  Demo #59.
//
// The codegen corner: **64-bit integer <-> float conversion**.  A uint64 scale (spanning 1 .. 10^18,
// "nanometres to the cosmos") is converted to float to place it on a logarithmic ruler, and converted
// back to uint64 for the tick readout:
//   (float)v         -> __floatundisf (uint64 -> float32)
//   (uint64_t)fv     -> __fixunssfdi  (float32 -> uint64)
//   (float)(int64)v  -> __floatdisf   (int64  -> float32)  [signed sibling, also exercised]
// The soft-float demos #21/#33 only ever converted 32-bit ints to/from float; a 64-bit integer <-> float
// conversion is a wholly separate libcall set nothing in the first 58 demos emits.  (I use FLOAT, not
// double, to keep the ROM small and the per-frame work fast; the __float*di*df double siblings are the
// same conversion family.)
//
// WIDTH / SAFETY: scale stays < 10^18 (< 2^60), so (float)v never rounds up to >= 2^64 -> (uint64) is
// always defined (no overflow UB).  __floatundisf / __fixunssfdi are correctly-rounded -> bit-identical
// host vs target.  Float ops are one-per-statement (no FMA).  See docs/plans/2026-06-30-59-snes-cosmzoom.md.
#ifndef COSMZOOM_H
#define COSMZOOM_H

#include <stdint.h>

// Powers of ten, 10^0 .. 10^18 (all < 2^63).
static const uint64_t COSM_POW10[19] = {
    1ULL, 10ULL, 100ULL, 1000ULL, 10000ULL, 100000ULL, 1000000ULL, 10000000ULL, 100000000ULL,
    1000000000ULL, 10000000000ULL, 100000000000ULL, 1000000000000ULL, 10000000000000ULL,
    100000000000000ULL, 1000000000000000ULL, 10000000000000000ULL, 100000000000000000ULL,
    1000000000000000000ULL,
};

// Decade of v (0..18): the largest k with v >= 10^k.
static uint8_t cosm_decade(uint64_t v) {
    uint8_t d = 0u;
    for (uint8_t k = 1u; k < 19u; k++)
        if (v >= COSM_POW10[k]) d = k;
    return d;
}

// Ruler position of v, in 1/256ths of a decade (0 .. 18*256).  decade + fractional-within-decade, where
// the fraction is (v / 10^decade - 1) / 9, computed with 64-bit->float conversions (THE CORNER).
static uint16_t cosm_pos(uint64_t v) {
    uint8_t d = cosm_decade(v);
    float fv = (float)v;                    // __floatundisf (uint64 -> float)
    float fp = (float)COSM_POW10[d];        // __floatundisf
    float ratio = fv / fp;                  // in [1, 10)
    float t = ratio - 1.0f;
    float frac = t * 0.1111111f;            // /9  -> [0, 1)
    float scaled = frac * 256.0f;
    uint16_t f256 = (uint16_t)scaled;       // 0..255 within the decade
    return (uint16_t)((uint16_t)d * 256u + f256);
}

// Round-trip a scale through float and back to uint64 for the readout: __floatundisf then __fixunssfdi.
static uint64_t cosm_roundtrip(uint64_t v) {
    float fv = (float)v;                    // __floatundisf
    return (uint64_t)fv;                    // __fixunssfdi (float -> uint64) — low bits lost, deterministic
}

// Signed sibling: convert an int64 delta to float and back (__floatdisf / __fixsfdi).
static int64_t cosm_signed_rt(int64_t v) {
    float fv = (float)v;                    // __floatdisf (int64 -> float)
    return (int64_t)fv;                     // __fixsfdi
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t cosm_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 90u
#endif

// Fold the ruler position + the uint64<->float round-trip + the signed int64<->float round-trip over a
// sequence of scales spanning all 18 decades.  A miscompile in any of the 64-bit conversion libcalls
// diverges.  Round-trip values are folded as 16-bit slices so a lost/added bit shows.
static uint16_t cosm_gate_crc(void) {
    uint16_t h = 0u;
    uint64_t scale = 1u;
    for (uint16_t i = 0u; i < (uint16_t)GATE_N; i++) {
        // advance the scale multiplicatively but keep it < 10^18
        scale = scale + (scale >> 2) + 1u;          // ~*1.25 growth
        if (scale >= COSM_POW10[18]) scale = 1u + (uint64_t)(i * 7u);
        uint16_t pos = cosm_pos(scale);
        uint64_t rt = cosm_roundtrip(scale);
        int64_t  sr = cosm_signed_rt(-(int64_t)scale);
        h = cosm_fold(h, pos);
        h = cosm_fold(h, (uint16_t)rt);
        h = cosm_fold(h, (uint16_t)(rt >> 32));
        h = cosm_fold(h, (uint16_t)((uint64_t)sr));
        h = cosm_fold(h, (uint16_t)((uint64_t)sr >> 48));
    }
    return h;
}

#endif /* COSMZOOM_H */
