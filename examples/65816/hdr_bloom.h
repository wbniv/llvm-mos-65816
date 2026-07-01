// Shared, PURE HDR additive-bloom field — host-linkable, no hardware.  Demo #44.
//
// The codegen corner: **saturating / overflow-checked arithmetic** via `__builtin_add_overflow`.
// Many overlapping translucent glows are summed per cell; each add saturates (clamps to white)
// instead of wrapping, so where lights pile up the field blows out to maximum — the "HDR bloom"
// look.  `__builtin_add_overflow` lowers to a carry/overflow-flag test + branch (adc; bcs) — a
// flag-testing add sequence no other demo in the battery exercises.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - the intensity field is uint8_t (0..255); the saturating add clamps at 255
//   - light positions are Q4 fixed point in int16_t (cell << 4); velocities int16_t
//   - no bare int; the only multiplies are the once-per-init kernel build
//
// See docs/plans/2026-06-30-44-snes-hdr-bloom.md.
#ifndef HDR_BLOOM_H
#define HDR_BLOOM_H

#include <stdint.h>

// ---------------------------------------------------------------------------------------------
// Field geometry

#define BLOOM_W    32u
#define BLOOM_H    28u
#define BLOOM_N    (BLOOM_W * BLOOM_H)

#define BLOOM_LIGHTS  6u        // number of drifting glows
#define BLOOM_R       5         // kernel radius in cells (footprint = (2R+1)^2 = 121)
#define BLOOM_KW      (2 * BLOOM_R + 1)
#define BLOOM_PEAK    200u      // per-light centre contribution (so ~2 overlapping lights clamp)

// ---------------------------------------------------------------------------------------------
// The saturating add — the whole point of the demo.

static inline uint8_t bloom_sat_add8(uint8_t a, uint8_t b) {
    uint8_t r;
    return __builtin_add_overflow(a, b, &r) ? (uint8_t)0xFFu : r;
}

// ---------------------------------------------------------------------------------------------
// State

typedef struct {
    int16_t x[BLOOM_LIGHTS];    // Q4 cell position (cell << 4)
    int16_t y[BLOOM_LIGHTS];
    int16_t vx[BLOOM_LIGHTS];   // Q4 velocity
    int16_t vy[BLOOM_LIGHTS];
    uint8_t field[BLOOM_N];     // intensity buffer (rebuilt each step)
    uint8_t kernel[BLOOM_KW * BLOOM_KW];  // radial glow stamp (built once)
    uint16_t clamped;           // count of cells at 255 last step (the "blown-out" stat)
} bloom_state;

// Build the radial kernel once: contribution falls off with squared distance, 0 outside radius.
static void bloom_build_kernel(bloom_state *s) {
    for (int16_t ky = -BLOOM_R; ky <= BLOOM_R; ky++) {
        for (int16_t kx = -BLOOM_R; kx <= BLOOM_R; kx++) {
            int16_t d2 = (int16_t)(kx * kx + ky * ky);
            int16_t r2 = (int16_t)(BLOOM_R * BLOOM_R);
            uint8_t v = 0u;
            if (d2 <= r2)
                v = (uint8_t)((uint16_t)BLOOM_PEAK * (uint16_t)(r2 - d2) / (uint16_t)r2);
            s->kernel[(uint16_t)(ky + BLOOM_R) * BLOOM_KW + (uint16_t)(kx + BLOOM_R)] = v;
        }
    }
}

// Deterministic initial light layout (fixed positions + velocities → same on host and target).
static void bloom_init(bloom_state *s) {
    // Spread lights across the field with distinct slow velocities.
    // Two lights start clustered near centre (guaranteed overlap → clamp from step 1); the rest
    // drift in from the edges so blowout regions form and dissolve as they cross.
    static const int16_t px[BLOOM_LIGHTS] = { 14, 17,  4, 28,  6, 26 };
    static const int16_t py[BLOOM_LIGHTS] = { 13, 13,  4,  5, 22, 21 };
    static const int16_t vX[BLOOM_LIGHTS] = {  3, -3,  5, -6,  4, -5 };
    static const int16_t vY[BLOOM_LIGHTS] = {  2, -2,  6,  4, -5,  3 };
    for (uint16_t i = 0; i < BLOOM_LIGHTS; i++) {
        s->x[i]  = (int16_t)(px[i] << 4);
        s->y[i]  = (int16_t)(py[i] << 4);
        s->vx[i] = vX[i];
        s->vy[i] = vY[i];
    }
    for (uint16_t i = 0; i < BLOOM_N; i++) s->field[i] = 0u;
    s->clamped = 0u;
    bloom_build_kernel(s);
}

// Advance one frame: move each light (bounce at edges), clear the field, then stamp every light's
// glow with the SATURATING add.  Overlaps clamp to 255 = white blowout.
static void bloom_step(bloom_state *s) {
    // Move + bounce (Q4 positions; clamp to [0, (W-1)<<4]).
    for (uint16_t i = 0; i < BLOOM_LIGHTS; i++) {
        int16_t nx = (int16_t)(s->x[i] + s->vx[i]);
        int16_t ny = (int16_t)(s->y[i] + s->vy[i]);
        if (nx < 0)                          { nx = 0;                             s->vx[i] = (int16_t)-s->vx[i]; }
        else if (nx > (int16_t)((BLOOM_W - 1u) << 4)) { nx = (int16_t)((BLOOM_W - 1u) << 4); s->vx[i] = (int16_t)-s->vx[i]; }
        if (ny < 0)                          { ny = 0;                             s->vy[i] = (int16_t)-s->vy[i]; }
        else if (ny > (int16_t)((BLOOM_H - 1u) << 4)) { ny = (int16_t)((BLOOM_H - 1u) << 4); s->vy[i] = (int16_t)-s->vy[i]; }
        s->x[i] = nx; s->y[i] = ny;
    }

    for (uint16_t i = 0; i < BLOOM_N; i++) s->field[i] = 0u;

    for (uint16_t i = 0; i < BLOOM_LIGHTS; i++) {
        int16_t cx = (int16_t)(s->x[i] >> 4), cy = (int16_t)(s->y[i] >> 4);
        for (int16_t ky = -BLOOM_R; ky <= BLOOM_R; ky++) {
            int16_t fy = (int16_t)(cy + ky);
            if (fy < 0 || fy >= (int16_t)BLOOM_H) continue;
            const uint8_t *krow = &s->kernel[(uint16_t)(ky + BLOOM_R) * BLOOM_KW];
            uint8_t *frow = &s->field[(uint16_t)fy * BLOOM_W];
            for (int16_t kx = -BLOOM_R; kx <= BLOOM_R; kx++) {
                int16_t fx = (int16_t)(cx + kx);
                if (fx < 0 || fx >= (int16_t)BLOOM_W) continue;
                frow[fx] = bloom_sat_add8(frow[fx], krow[(uint16_t)(kx + BLOOM_R)]);
            }
        }
    }
}

// Count blown-out cells (clamped at 255) — the HDR stat.  Split out of bloom_step so the
// per-frame display path stays cheap (the demo doesn't need the count; only the gate folds it).
static uint16_t bloom_count_clamped(bloom_state *s) {
    uint16_t c = 0;
    for (uint16_t i = 0; i < BLOOM_N; i++) if (s->field[i] == 0xFFu) c++;
    s->clamped = c;
    return c;
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t bloom_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_STEPS
#define GATE_STEPS 12u
#endif

static uint16_t hdr_bloom_gate_crc(void) {
    static bloom_state s;
    bloom_init(&s);
    uint16_t h = 0;
    for (uint16_t t = 0; t < (uint16_t)GATE_STEPS; t++) {
        bloom_step(&s);
        h = bloom_fold(h, bloom_count_clamped(&s));
        // fold a diagonal sample of the field so any mis-saturation diverges the CRC
        for (uint16_t i = 0; i < BLOOM_W && i < BLOOM_H; i++)
            h = bloom_fold(h, s.field[i * BLOOM_W + i]);
    }
    return h;
}

#endif /* HDR_BLOOM_H */
