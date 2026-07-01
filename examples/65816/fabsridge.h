// Fabs Ridgeline (#80) — shared, portable logic header.
//
// Stresses G_FABS via __builtin_fabsf(x) as the hot per-column op in the tent-map
// iteration, targeting the TARGET-CUSTOM path legalizeFAbs at MOSLegalizerInfo.cpp:369:
//   inline AND src, inverted-getSignMask(32) = AND with 0x7FFFFFFF
// No fabsf libcall — the sign-bit clear is emitted entirely inline.
// Distinct from #57 medfilt (integer G_ABS at :281) and #45 metaball (union type-pun
// through the integer ALU, never the float sign-bit AND path).
//
// Algorithm: tent map with fabsf as the absolute-value core.
//   x_next = 1.0f - fabsf(2.0f * x - 1.0f)
// The tent map is the chaotic map on [0,1] with a V-notch kink at x=0.5.
// Each float op is a SEPARATE STATEMENT so the compiler cannot fuse them into an FMA.
//   2.0f * x       -> __mulsf3
//   two_x - 1.0f   -> __subsf3
//   fabsf(shifted) -> G_FABS custom legalizeFAbs (inline AND)
//   1.0f - abs_val -> __subsf3
//
// Visual: 16-column terrain silhouette on a 128x128 BG3 tile canvas.  Each tile column
// gets a ridge height derived from its tent-map seed + animation tick; sky/medium/dark
// terrain fills the 16-row column.  As the tick advances the terrain undulates.
//
// WIDTH DISCIPLINE: all integer values uint16_t; no bare int; float for the tent map.
// DIFFERENTIAL: correctly-rounded soft-float — fabsf is an EXACT single-bit operation
// (same bit result host and target); other ops one-per-statement, no FMA; heights are
// integer-truncated and bit-identical host vs target; any wrong G_FABS lowering
// (e.g. forgetting to clear the sign bit) produces wrong tent-map values and diverges CRC.
// GATE_N = 120 (not a multiple of 16) avoids the degenerate rotate-period cancellation
// where CRC(0, 128 iterations) = 0 due to the 16-bit rotate having period 16.
// See docs/plans/2026-07-01-80-snes-fabsridge.md.

#ifndef FABSRIDGE_H
#define FABSRIDGE_H

#include <stdint.h>

// One tent-map step: x_next = 1 - |2x - 1|.
// Each float op is a separate statement — prevents FMA fusion on any target.
static inline float fr_tent(float x) {
    float two_x   = 2.0f * x;          // __mulsf3
    float shifted = two_x - 1.0f;      // __subsf3
    float abs_val = __builtin_fabsf(shifted);  // G_FABS: legalizeFAbs inline AND
    float next    = 1.0f - abs_val;    // __subsf3
    return next;
}

// Height (0..CANVAS_H-1) for column col at animation tick t.
// Seed: hash to (0.05, 1.0) avoiding fixed points x=0 and x=1.
static inline uint16_t fr_height(uint16_t col, uint16_t t, uint16_t canvas_h) {
    // hash & 0x7F gives 0..127; /128.0f gives [0,0.992]; +0.05f gives [0.05,1.042]
    uint16_t hash = (uint16_t)((uint16_t)((uint16_t)(col * (uint16_t)7u) + t + (uint16_t)13u)
                               & (uint16_t)0x7Fu);
    float x = (float)hash / 128.0f + 0.05f;
    if (x >= 1.0f) x = x - 1.0f;   // fold into [0.05, 1.0) — at most one subtraction
    // Three tent-map iterations; fabsf is the hot op.
    x = fr_tent(x);
    x = fr_tent(x);
    x = fr_tent(x);
    return (uint16_t)(x * (float)canvas_h);
}

// CRC fold step (rotating XOR).
static inline uint16_t fr_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// --------------------------------------------------------------------------
// Differential gate: fold fr_height() for GATE_N columns at t=0.
// GATE_N = 120 (not a multiple of 16 — avoids rotate-period cancellation).
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 120u
#endif

static uint16_t fabsridge_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    for (uint16_t col = (uint16_t)0u; col < (uint16_t)GATE_N; col++) {
        uint16_t height = fr_height(col, (uint16_t)0u, (uint16_t)127u);
        h = fr_fold(h, height);
    }
    return h;
}

#endif /* FABSRIDGE_H */
