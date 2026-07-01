// Funnel-Shift Kaleidoscope (#73) — shared, portable logic header.
//
// Stresses G_FSHL/G_FSHR two-source funnel shift (.lower() at MOSLegalizerInfo.cpp:317):
//   __builtin_elementwise_fshl(A,B,k) and __builtin_elementwise_fshr(B,A,k) with A != B,
//   so matchFunnelShiftToRotate refuses to fold either call into a G_ROTL/G_ROTR.
//   The default "terrible" double-source shift+or expansion fires for both:
//     fshl(A,B,k) -> (A << k) | (B >> (16-k))     -- left funnel
//     fshr(B,A,k) -> (B << (16-k)) | (A >> k)     -- right funnel (args swapped too)
//   Neither prior demo ever emitted a two-source funnel node.
//
// Visual: 8-fold-symmetric mandala on the 128x128 BG3 canvas.  Each tile (tx,ty)
// in [0..15]^2 is octant-folded to (ox,oy) with ox<=oy, so the tile shares colour
// with its 7 reflections.  A and B are INDEPENDENT linear combinations of (ox,oy,t)
// so they are provably not equal -> matchFunnelShiftToRotate cannot fire.
// Color = top 2 bits of the 4-bit value (top nibble of L^R), giving 2bpp palette index.
//
// WIDTH DISCIPLINE: all values uint16_t/int16_t; no bare int; no float; no division.
// DIFFERENTIAL: integer-exact.  Funnel shift of uint16_t is a pure bitwise operation,
// bit-identical host vs target; any wrong lowering (e.g. treating as rotate when A!=B)
// diverges the CRC.
//
// The __builtin_elementwise_fshl/fshr builtins are clang-only (LLVM >= 14).  The host
// (gcc) oracle uses the bit-identical manual expansion (verified to match clang output).
// See docs/plans/2026-07-01-73-snes-funnelkal.md.

#ifndef FUNNELKAL_H
#define FUNNELKAL_H

#include <stdint.h>

// ------------------------------------------------------------------
// Portable funnel-shift macros.
// clang: uses the genuine builtin -> exercises G_FSHL/G_FSHR legalizer.
// gcc host: manual bit-identical expansion (the same semantics).
// ------------------------------------------------------------------
#ifdef __clang__
#  define FK_FSHL(A,B,K) \
     ((uint16_t)__builtin_elementwise_fshl((uint16_t)(A),(uint16_t)(B),(uint16_t)(K)))
#  define FK_FSHR(HI,LO,K) \
     ((uint16_t)__builtin_elementwise_fshr((uint16_t)(HI),(uint16_t)(LO),(uint16_t)(K)))
#else
// Manual reference: fshl(a,b,k) = (a<<k)|(b>>(16-k)) for k in [1..15], = a for k=0.
static inline uint16_t _fk_fshl(uint16_t a, uint16_t b, uint16_t k) {
    k = (uint16_t)(k & (uint16_t)15u);
    return (k == (uint16_t)0u)
        ? a
        : (uint16_t)(((unsigned)a << k) | ((unsigned)b >> (16u - k)));
}
// Manual reference: fshr(hi,lo,k) = (hi<<(16-k))|(lo>>k) for k in [1..15], = lo for k=0.
static inline uint16_t _fk_fshr(uint16_t hi, uint16_t lo, uint16_t k) {
    k = (uint16_t)(k & (uint16_t)15u);
    return (k == (uint16_t)0u)
        ? lo
        : (uint16_t)(((unsigned)hi << (16u - k)) | ((unsigned)lo >> k));
}
#  define FK_FSHL(A,B,K)    _fk_fshl((uint16_t)(A),(uint16_t)(B),(uint16_t)(K))
#  define FK_FSHR(HI,LO,K)  _fk_fshr((uint16_t)(HI),(uint16_t)(LO),(uint16_t)(K))
#endif

// ------------------------------------------------------------------
// Funnel sources: two INDEPENDENT linear combinations of (ox,oy,t).
// Coefficient sets are coprime and distinct; 0xA5A5 bias ensures A != B
// even when ox=oy=t=0.
// ------------------------------------------------------------------
static inline uint16_t fk_src_A(uint16_t ox, uint16_t oy, uint16_t t) {
    return (uint16_t)((uint16_t)(ox * (uint16_t)17u)
                    + (uint16_t)(oy * (uint16_t)7u)
                    + (uint16_t)(t  * (uint16_t)5u));
}
static inline uint16_t fk_src_B(uint16_t ox, uint16_t oy, uint16_t t) {
    return (uint16_t)((uint16_t)(ox * (uint16_t)11u)
                    + (uint16_t)(oy * (uint16_t)13u)
                    + (uint16_t)(t  * (uint16_t)3u)
                    + (uint16_t)0xA5A5u);
}

// Funnel shift count: mix of position + time, masked to [0..15].
static inline uint16_t fk_shift_k(uint16_t ox, uint16_t oy, uint16_t t) {
    return (uint16_t)((uint16_t)(ox
                    + (uint16_t)(oy * (uint16_t)3u)
                    + t) & (uint16_t)15u);
}

// Absolute value of int16_t -> uint16_t (safe: input range [-64..64]).
static inline uint16_t fk_abs16(int16_t x) {
    return (x < (int16_t)0) ? (uint16_t)(-(int16_t)x) : (uint16_t)x;
}

// ------------------------------------------------------------------
// Per-tile colour for the mandala.
// tx, ty in [0..15]; t is the animation tick.
// Returns a 4-bit value (0..15) from the top nibble of L^R.
// ------------------------------------------------------------------
static inline uint16_t fk_cell(uint16_t tx, uint16_t ty, uint16_t t) {
    // Signed center-relative coords (canvas center is at px=64,py=64).
    int16_t dx = (int16_t)((int16_t)((uint16_t)(tx * (uint16_t)8u + (uint16_t)4u)) - (int16_t)64);
    int16_t dy = (int16_t)((int16_t)((uint16_t)(ty * (uint16_t)8u + (uint16_t)4u)) - (int16_t)64);
    // Octant folding: abs then sort so ox <= oy -> 8-fold symmetry.
    uint16_t ax = fk_abs16(dx);
    uint16_t ay = fk_abs16(dy);
    uint16_t ox = (ax < ay) ? ax : ay;
    uint16_t oy = (ax < ay) ? ay : ax;

    uint16_t A = fk_src_A(ox, oy, t);
    uint16_t B = fk_src_B(ox, oy, t);   // != A (different coeffs + 0xA5A5 bias)
    uint16_t k = fk_shift_k(ox, oy, t); // runtime variable, 0..15

    // Two-source funnel shifts: A!=B so matchFunnelShiftToRotate cannot simplify.
    // L = fshl(A,B,k) = (A<<k)|(B>>(16-k))
    // R = fshr(B,A,k) = (B<<(16-k))|(A>>k)
    uint16_t L = FK_FSHL(A, B, k);
    uint16_t R = FK_FSHR(B, A, k);

    return (uint16_t)((uint16_t)(L ^ R) >> (uint16_t)12u);  // top 4 bits [0..15]
}

// BG3 2bpp colour index (0..3) from cell value.
static inline uint8_t fk_color(uint16_t v) {
    return (uint8_t)((uint8_t)(v & (uint16_t)3u));
}

// CRC fold step (rotating XOR).
static inline uint16_t fk_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// ------------------------------------------------------------------
// Differential gate: fold fk_cell() for all 256 tiles (16x16 grid).
// GATE_N = 256: one pass over the complete tile grid, t = i>>2.
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 256u
#endif

static uint16_t funnelkal_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        uint16_t tx = (uint16_t)(i & (uint16_t)15u);
        uint16_t ty = (uint16_t)((i >> (uint16_t)4u) & (uint16_t)15u);
        uint16_t t  = (uint16_t)(i >> (uint16_t)2u);
        h = fk_fold(h, fk_cell(tx, ty, t));
    }
    return h;
}

#endif /* FUNNELKAL_H */
