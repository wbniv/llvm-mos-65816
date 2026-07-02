// Speed Cap Particles (#82) — shared, portable logic header.
//
// Stresses:
//   __builtin_fminf(a, b) → G_FMINNUM → .libcallFor S32 → fminf (math.cc:18)
//   __builtin_fmaxf(a, b) → G_FMAXNUM → .libcallFor S32 → fmaxf (math.cc:19)
// Both lower via .libcallFor S32 (not inline) — the only fmin/fmax impl in the SDK.
// NaN-quieting: fmaxf(NaN, -MAX_V) = -MAX_V — NaN input silenced to a number.
// Distinct from:
//   #77 satcast: fmin/fmax used as saturating-cast clamp before G_FPTOSI (hex kaleidoscope)
//   #26 boids: integer fixed-point aggregate-return ABI (NO float, NO fminf/fmaxf)
//   #45 metaball: union float/uint32 type-pun, never G_FMINNUM
//
// Algorithm: 12 particles attracted to a fixed center; float velocity double-clamped
// by fminf(fmaxf(v, -MAX_V), MAX_V). The clamp fires from step ~8 (attraction builds
// speed past MAX_V before position converges). Position update via int16 truncation.
//
// WIDTH DISCIPLINE: all integer ops use int16_t/uint16_t; no bare int.
// DIFFERENTIAL: integer-exact — fminf/fmaxf on values in [-8..8] select one input
// (no rounding); float→int16 truncation is exact for values in [-8,8].
// Any fmin/fmax miscompile diverges the position fold and breaks the CRC immediately.
//
// See docs/plans/2026-07-01-82-snes-speedcap.md.

#ifndef SPEEDCAP_H
#define SPEEDCAP_H

#include <stdint.h>

#define SC_N        12u            // number of particles
#define SC_CENTER_X ((int16_t)64)  // canvas center x (128×128 canvas → 64)
#define SC_CENTER_Y ((int16_t)64)  // canvas center y
#define SC_K        0.02f          // centripetal attraction coefficient
#define SC_MAX_V    8.0f           // speed governor cap (pixels/frame per axis)
#ifndef SC_GATE_N
#define SC_GATE_N   16u            // simulation steps in gate CRC
// Note: fminf/fmaxf are expensive libcalls (~3k-8k cycles each on 65816).
// 12 particles × 16 steps × 12 float-ops × ~5k cycles = ~11M cycles ≈ 123 V-blanks.
// This fits within the 120-frame title hold + well before the 500-frame capture.
// The speed cap fires from step ~8, so all 16 steps exercise the fmin/fmax path.
#endif

// Initial positions: 12 particles on a circle of radius 48 centred at (64,64).
// Precomputed from i*30°, y-axis down:
//   px = 64 + round(48*cos(i*30°)),  py = 64 - round(48*sin(i*30°))
static const int16_t SC_INIT_PX[SC_N] = {
     64,  88, 105, 112, 105,  88,  64,  40,  23,  16,  23,  40
};
static const int16_t SC_INIT_PY[SC_N] = {
     16,  23,  40,  64,  88, 105, 112, 105,  88,  64,  40,  23
};

// ------------------------------------------------------------------
// Gate CRC: GATE_N steps, fold all positions.
// fminf/fmaxf double-clamp is the codegen corner tested.
// No NaN in gate — NaN injection is ROM-visual-only.
// ------------------------------------------------------------------
static uint16_t speedcap_gate_crc(void) {
    int16_t px[SC_N], py[SC_N];
    float   vx[SC_N], vy[SC_N];
    uint16_t i;
    for (i = 0u; i < (uint16_t)SC_N; i++) {
        px[i] = SC_INIT_PX[i];
        py[i] = SC_INIT_PY[i];
        vx[i] = 0.0f;
        vy[i] = 0.0f;
    }

    uint16_t h = 0u;
    uint16_t step;
    for (step = 0u; step < (uint16_t)SC_GATE_N; step++) {
        for (i = 0u; i < (uint16_t)SC_N; i++) {
            // Centripetal attraction — one op per statement, no FMA.
            float dx = (float)((int16_t)(SC_CENTER_X - px[i]));   // G_SITOFP → __floatsisf
            float dy = (float)((int16_t)(SC_CENTER_Y - py[i]));
            float sdx = dx * SC_K;                                  // G_FMUL   → __mulsf3
            float sdy = dy * SC_K;
            float nvx = vx[i] + sdx;                               // G_FADD   → __addsf3
            float nvy = vy[i] + sdy;
            // Speed governor: G_FMAXNUM → fmaxf; G_FMINNUM → fminf (both libcalls).
            vx[i] = __builtin_fminf(__builtin_fmaxf(nvx, -SC_MAX_V), SC_MAX_V);
            vy[i] = __builtin_fminf(__builtin_fmaxf(nvy, -SC_MAX_V), SC_MAX_V);
            // Integer position update — truncation exact for values in [-8,8].
            int16_t ivx = (int16_t)vx[i];    // G_FPTOSI → __fixsfsi, then trunc to i16
            int16_t ivy = (int16_t)vy[i];
            px[i] = (int16_t)(px[i] + ivx);
            py[i] = (int16_t)(py[i] + ivy);
        }
        // Fold positions with prime multipliers (breaks XOR-cancel symmetry).
        for (i = 0u; i < (uint16_t)SC_N; i++) {
            h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
            h = (uint16_t)(h ^ (uint16_t)(
                (uint16_t)((int16_t)px[i] * (int16_t)97) ^
                (uint16_t)((int16_t)py[i] * (int16_t)13)
            ));
        }
    }
    return h;
}

#endif /* SPEEDCAP_H */
