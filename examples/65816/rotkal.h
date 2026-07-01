// Rotate-Register Kaleidoscope (#74) — shared, portable logic header.
//
// Stresses G_ROTL/G_ROTR via __builtin_rotateleft8/right8/rotateleft16:
//   - CONSTANT per-ring amounts on uint8_t registers (1,2,3,1 left; 1,2,3,1 right)
//     -> hits ConstantAmt fast path in legalizeShiftRotate (MOSLegalizerInfo.cpp:1046-1061)
//     -> S8 special case for 8-bit rotates (MOSLegalizerInfo.cpp:1167-1178)
//   - RUNTIME amount on uint16_t outer word (k derived from frame counter)
//     -> hits the runtime-amount expansion path
//   No prior demo used __builtin_rotateleft*/rotateright* — confirms zero coverage before.
//
// Visual: 8-fold kaleidoscope mandala on 128x128 BG3 tile canvas.
// State: 8 uint8_t ring registers (one per Chebyshev-distance ring from center) +
//        1 uint16_t outer word for the runtime rotate.
// Per-frame: constant-speed rotation of each ring register (different bit counts per ring)
//            + runtime rotation of outer by k = (frame & 14) + 1 (always non-zero).
// Color: 2 bits extracted from the ring register for the tile's ring band,
//        XOR'd with top 2 bits of outer word for cross-ring shimmer.
//
// WIDTH DISCIPLINE: all values uint8_t/uint16_t; no bare int; no float; no division.
// DIFFERENTIAL: integer-exact — bitwise rotates of fixed-width unsigned types are
// bit-defined identically host vs target; any wrong lowering (missing bit, wrong direction)
// diverges the CRC across compile modes.
//
// See docs/plans/2026-07-01-74-snes-rotkal.md.

#ifndef ROTKAL_H
#define ROTKAL_H

#include <stdint.h>

// ------------------------------------------------------------------
// Portable rotate macros.
// clang: genuine builtins -> exercises G_ROTL/G_ROTR legalizer.
// gcc host: manual bit-identical expansions (verified semantics).
// ------------------------------------------------------------------
#ifdef __clang__
#  define RK_ROT8L(x, n)  __builtin_rotateleft8((uint8_t)(x),   (unsigned char)(n))
#  define RK_ROT8R(x, n)  __builtin_rotateright8((uint8_t)(x),  (unsigned char)(n))
#  define RK_ROT16L(x, n) __builtin_rotateleft16((uint16_t)(x), (unsigned short)(n))
#else
// Manual reference — bit-identical to the clang builtins for valid inputs.
static inline uint8_t _rk_rot8l(uint8_t x, unsigned n) {
    n &= 7u;
    return (uint8_t)(n ? (unsigned)((unsigned)x << n | (unsigned)x >> (8u - n)) : (unsigned)x);
}
static inline uint8_t _rk_rot8r(uint8_t x, unsigned n) {
    n &= 7u;
    return (uint8_t)(n ? (unsigned)((unsigned)x >> n | (unsigned)x << (8u - n)) : (unsigned)x);
}
static inline uint16_t _rk_rot16l(uint16_t x, unsigned n) {
    n &= 15u;
    return (uint16_t)(n ? (unsigned)((unsigned)x << n | (unsigned)x >> (16u - n)) : (unsigned)x);
}
#  define RK_ROT8L(x, n)  _rk_rot8l((uint8_t)(x),  (unsigned)(n))
#  define RK_ROT8R(x, n)  _rk_rot8r((uint8_t)(x),  (unsigned)(n))
#  define RK_ROT16L(x, n) _rk_rot16l((uint16_t)(x), (unsigned)(n))
#endif

// ------------------------------------------------------------------
// Kaleidoscope state: 8 ring registers + 1 outer word.
// ------------------------------------------------------------------
typedef struct {
    uint8_t  ring[8];   // one per Chebyshev-distance ring (0=center .. 7=outer edge)
    uint16_t outer;     // 16-bit register for the runtime-amount rotate
} RKState;

static inline void rk_init(RKState *s) {
    // Distinct prime-derived seeds so all rings start at different phases.
    s->ring[0] = (uint8_t)0xA3u;
    s->ring[1] = (uint8_t)0x5Cu;
    s->ring[2] = (uint8_t)0xE1u;
    s->ring[3] = (uint8_t)0x78u;
    s->ring[4] = (uint8_t)0x2Fu;
    s->ring[5] = (uint8_t)0x94u;
    s->ring[6] = (uint8_t)0xB7u;
    s->ring[7] = (uint8_t)0x1Du;
    s->outer   = (uint16_t)0xABCDu;
}

// Advance state one step.
// k: runtime rotation amount for the outer 16-bit register (caller ensures k in [1..15]).
// The constant amounts for ring[0..7] exercise the ConstantAmt fast path.
// The runtime k exercises the runtime-amount lowering path.
__attribute__((noinline))
static void rk_step(RKState *s, uint16_t k) {
    // Constant left rotates — ConstantAmt path (legalizeShiftRotate 1046-1061)
    // + S8 special case (1167-1178) for 8-bit width.
    s->ring[0] = RK_ROT8L(s->ring[0], 1);
    s->ring[1] = RK_ROT8L(s->ring[1], 2);
    s->ring[2] = RK_ROT8L(s->ring[2], 3);
    s->ring[3] = RK_ROT8L(s->ring[3], 1);
    // Constant right rotates — exercises ROR lowering path.
    s->ring[4] = RK_ROT8R(s->ring[4], 1);
    s->ring[5] = RK_ROT8R(s->ring[5], 2);
    s->ring[6] = RK_ROT8R(s->ring[6], 3);
    s->ring[7] = RK_ROT8R(s->ring[7], 1);
    // Runtime-amount 16-bit left rotate — exercises the variable-amount path.
    s->outer = RK_ROT16L(s->outer, (unsigned short)k);
}

// Per-tile colour (2bpp, 0..3) for the kaleidoscope mandala.
// tx, ty in [0..15]; s is the current state after some number of rk_step() calls.
static inline uint8_t rk_cell(const RKState *s, uint16_t tx, uint16_t ty) {
    // Signed center-relative pixel coords (canvas center = 64,64).
    int16_t dx = (int16_t)((int16_t)((uint16_t)(tx * (uint16_t)8u + (uint16_t)4u)) - (int16_t)64);
    int16_t dy = (int16_t)((int16_t)((uint16_t)(ty * (uint16_t)8u + (uint16_t)4u)) - (int16_t)64);
    // Octant fold: 8-fold symmetry via abs + sort.
    uint16_t ax = (uint16_t)(dx < (int16_t)0 ? (uint16_t)(-(int16_t)dx) : (uint16_t)dx);
    uint16_t ay = (uint16_t)(dy < (int16_t)0 ? (uint16_t)(-(int16_t)dy) : (uint16_t)dy);
    uint16_t ox = (ax < ay) ? ax : ay;   // smaller (inner coord)
    uint16_t oy = (ax < ay) ? ay : ax;   // larger  (ring coord)

    // Ring index: Chebyshev distance in tile units (oy / 8 tile pixels), capped at 7.
    uint16_t ring_idx = (uint16_t)(oy >> (uint16_t)3u);
    if (ring_idx > (uint16_t)7u) ring_idx = (uint16_t)7u;

    // Extract 2 bits from the ring's byte register, offset by inner coord (0..7).
    uint16_t bit_pos  = (uint16_t)(ox & (uint16_t)7u);
    uint16_t ring_val = (uint16_t)((uint16_t)((uint16_t)s->ring[ring_idx] >> bit_pos) & (uint16_t)3u);

    // XOR with top 2 bits of outer word for cross-ring shimmer effect.
    uint16_t outer_bits = (uint16_t)((uint16_t)(s->outer >> (uint16_t)14u) & (uint16_t)3u);
    return (uint8_t)((ring_val ^ outer_bits) & (uint16_t)3u);
}

// CRC fold step (rotating XOR).
static inline uint16_t rk_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// ------------------------------------------------------------------
// Differential gate: GATE_N steps; fold all ring registers + outer
// after each step.  k = (i & 14) + 1 ensures runtime non-zero shift.
// GATE_N = 100 (not a multiple of 8 — the ring+outer state period is
// lcm(8,8) = 8, so multiples of 8 yield CRC=0x0000; 100 gives 0x300C).
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 100u
#endif

static uint16_t rotkal_gate_crc(void) {
    RKState s;
    rk_init(&s);
    uint16_t h = (uint16_t)0u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        uint16_t k = (uint16_t)((uint16_t)(i & (uint16_t)14u) + (uint16_t)1u);  // 1..15
        rk_step(&s, k);
        uint16_t r;
        for (r = (uint16_t)0u; r < (uint16_t)8u; r++) {
            h = rk_fold(h, (uint16_t)s.ring[r]);
        }
        h = rk_fold(h, s.outer);
    }
    return h;
}

#endif /* ROTKAL_H */
