// Saturating Palette Comet Trails (#75) — shared, portable logic header.
//
// Stresses ALL FOUR saturating-add/sub operations via __builtin_elementwise_add_sat /
// __builtin_elementwise_sub_sat on BOTH unsigned uint8_t (glow/decay) and signed int16_t
// (velocity kicks), routing to G_UADDSAT / G_USUBSAT / G_SADDSAT / G_SSUBSAT all via
// `.lower()` at MOSLegalizerInfo.cpp:246 -> lowerAddSubSatToMinMax (branchless min/max).
//
// Distinct from:
//   #44 hdr-bloom: __builtin_add_overflow -> G_UADDO (flag-test+branch, NOT saturating)
//   #70 dither: hand-written ternary -> G_ICMP+G_SELECT (not the sat-intrinsic legalizer)
//
// Algorithm:
//   glow[GW][GW] uint8_t: per-tile brightness field (16x16 tile grid)
//   6 comets: (px,py) uint8_t tile pos, (vx,vy) int8_t velocity
//   Per step t:
//     decay all tiles:  glow[y][x] = USUB_SAT8(glow[y][x], 8)
//     per comet:
//       brighten:  glow[cy][cx] = UADD_SAT8(glow[cy][cx], 100)
//       kick vx:   vx = SADD_SAT16(vx, +/-1)  <- signed sat!
//       kick vy:   vy = SSUB_SAT16(vy, 0/1)   <- signed sat!
//       move:      px = (px + vx) & 15; py = (py + vy) & 15
//   Gate CRC: fold all 256 glow[y][x] values after GATE_N steps.
//
// The __builtin_elementwise_add_sat/sub_sat builtins are clang-only (not gcc).
// The host (gcc) oracle uses the bit-identical manual clamp implementations.
//
// WIDTH DISCIPLINE: glow is uint8_t; velocities are int8_t (stored) / int16_t (computation);
// no bare int; no float. DIFFERENTIAL: integer-exact — saturating clamp is bitwise-defined
// (max(0,a-b) for unsigned sub, min(255,a+b) for unsigned add) identical host vs target.
// See docs/plans/2026-07-01-75-snes-satcomet.md.

#ifndef SATCOMET_H
#define SATCOMET_H

#include <stdint.h>
/* No string.h — target is bare-metal; memset replaced by manual loop in sc_init. */

// ------------------------------------------------------------------
// Portable saturating operation macros.
// clang: uses genuine builtins -> exercises G_UADDSAT/USUBSAT/SADDSAT/SSUBSAT.
// gcc host: manual bit-identical clamp (standard-defined, same result).
// ------------------------------------------------------------------
#ifdef __clang__
#  define SC_UADD8(a,b)  ((uint8_t)__builtin_elementwise_add_sat((uint8_t)(a),(uint8_t)(b)))
#  define SC_USUB8(a,b)  ((uint8_t)__builtin_elementwise_sub_sat((uint8_t)(a),(uint8_t)(b)))
#  define SC_SADD16(a,b) ((int16_t)__builtin_elementwise_add_sat((int16_t)(a),(int16_t)(b)))
#  define SC_SSUB16(a,b) ((int16_t)__builtin_elementwise_sub_sat((int16_t)(a),(int16_t)(b)))
#else
static inline uint8_t _sc_uadd8(uint8_t a, uint8_t b) {
    unsigned r = (unsigned)a + (unsigned)b;
    return (uint8_t)(r > 255u ? 255u : r);
}
static inline uint8_t _sc_usub8(uint8_t a, uint8_t b) {
    return a > b ? (uint8_t)(a - b) : (uint8_t)0u;
}
static inline int16_t _sc_sadd16(int16_t a, int16_t b) {
    int32_t r = (int32_t)a + (int32_t)b;
    return r > 32767 ? (int16_t)32767 : r < -32768 ? (int16_t)-32768 : (int16_t)r;
}
static inline int16_t _sc_ssub16(int16_t a, int16_t b) {
    int32_t r = (int32_t)a - (int32_t)b;
    return r > 32767 ? (int16_t)32767 : r < -32768 ? (int16_t)-32768 : (int16_t)r;
}
#  define SC_UADD8(a,b)   _sc_uadd8((uint8_t)(a),(uint8_t)(b))
#  define SC_USUB8(a,b)   _sc_usub8((uint8_t)(a),(uint8_t)(b))
#  define SC_SADD16(a,b)  _sc_sadd16((int16_t)(a),(int16_t)(b))
#  define SC_SSUB16(a,b)  _sc_ssub16((int16_t)(a),(int16_t)(b))
#endif

// ------------------------------------------------------------------
// Constants.
// ------------------------------------------------------------------
#define SC_GW       16u   // glow-field width and height (16x16 = 256 tiles)
#define SC_DECAY    8u    // uint8 decay per step
#define SC_BRIGHT   100u  // uint8 brightness added at comet position
#define SC_NC       6u    // number of comets

// ------------------------------------------------------------------
// Comet: (px,py) tile position [0..15], (vx,vy) signed velocity [-8..8].
// ------------------------------------------------------------------
typedef struct {
    uint8_t px, py;
    int8_t  vx, vy;
} SCComet;

// Initialise glow field (zeroed) and comets (fixed seeds).
static void sc_init(uint8_t glow[SC_GW][SC_GW], SCComet comets[SC_NC]) {
    // Manual zero — no string.h on bare-metal target.
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)SC_GW; y++)
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)SC_GW; x++)
            glow[y][x] = (uint8_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)SC_NC; i++) {
        comets[i].px = (uint8_t)(((uint8_t)(i * (uint8_t)2u) + (uint8_t)1u) & (uint8_t)15u);
        comets[i].py = (uint8_t)(((uint8_t)(i * (uint8_t)3u) + (uint8_t)1u) & (uint8_t)15u);
        comets[i].vx = (int8_t)((int8_t)1 + (int8_t)((int8_t)(i & 1u)));
        comets[i].vy = (int8_t)((int8_t)1 + (int8_t)((int8_t)((i >> 1u) & 1u)));
    }
}

// One simulation step: decay field, brighten comet tiles, apply saturating velocity kicks.
static void sc_step(uint8_t glow[SC_GW][SC_GW], SCComet comets[SC_NC], uint16_t t) {
    // Decay all tiles with UNSIGNED sub-saturate (floors at 0 — no wrap to 255).
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)SC_GW; y++) {
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)SC_GW; x++) {
            glow[y][x] = SC_USUB8(glow[y][x], (uint8_t)SC_DECAY);
        }
    }
    // Update each comet: brighten + saturating velocity kick + move.
    int16_t kick_x = (int16_t)((t & (uint16_t)1u) ? (int16_t)1 : (int16_t)-1);
    int16_t kick_y = (int16_t)((t & (uint16_t)2u) ? (int16_t)1 : (int16_t)-1);
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)SC_NC; i++) {
        SCComet *c = &comets[i];
        // UNSIGNED add-saturate: glow capped at 255 (no wrap).
        glow[c->py][c->px] = SC_UADD8(glow[c->py][c->px], (uint8_t)SC_BRIGHT);
        // SIGNED add/sub-saturate: velocity clamped to [-128,127] (int8 range).
        c->vx = (int8_t)SC_SADD16((int16_t)c->vx, kick_x);
        c->vy = (int8_t)SC_SSUB16((int16_t)c->vy, kick_y);
        c->px = (uint8_t)((uint8_t)((uint8_t)(c->px) + (uint8_t)c->vx) & (uint8_t)15u);
        c->py = (uint8_t)((uint8_t)((uint8_t)(c->py) + (uint8_t)c->vy) & (uint8_t)15u);
    }
}

// CRC fold step.
static inline uint16_t sc_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u)) ^ v);
}

// ------------------------------------------------------------------
// Differential gate: run GATE_N steps then fold the 16x16 glow field.
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 100u
#endif

static uint16_t satcomet_gate_crc(void) {
    static uint8_t glow[SC_GW][SC_GW];   // static to avoid large soft-stack frame
    static SCComet comets[SC_NC];
    sc_init(glow, comets);
    for (uint16_t t = (uint16_t)0u; t < (uint16_t)GATE_N; t++) {
        sc_step(glow, comets, t);
    }
    uint16_t h = (uint16_t)0u;
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)SC_GW; y++) {
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)SC_GW; x++) {
            h = sc_fold(h, (uint16_t)glow[y][x]);
        }
    }
    return h;
}

#endif /* SATCOMET_H */
