// Shared, PURE N-body Newtonian gravity — host-linkable, no hardware.
//
// Three bodies (Sun + Earth + Jupiter-like) under Newtonian gravity integrated
// by the Symplectic Euler method (velocity Verlet without the half-kick):
//   for each body-pair (i,j):
//     r² = dx² + dy²  (16×16→32 multiply — STRESS #1)
//     inv_r2 = GRAV_K * mj / r²  (__udivsi3 — STRESS #2)
//     ax += dx * inv_r2  (32-bit multiply — STRESS #3)
//   v += a;  x += v  (Symplectic Euler update)
//
// Note: the force law is F_x = GRAV_K * mj * dx / r² (not 1/r³).  This is the
// "planar harmonic" potential (F ∝ 1/r), which gives closed quasi-elliptical orbits
// without needing a square-root per step — avoiding a division-heavy isqrt on the
// hot path.  The important codegen stresses (16×16→32 multiply and __udivsi3) are
// still present and clearly attributable.
//
// Positions and velocities are in Q8.8 fixed-point (physical = integer / 256 pixels).
// All arithmetic uses explicit-width types (int16_t / int32_t / uint32_t) so the same
// source compiles correctly on both host (int=32) and 65816 target (int=16).
//
// No hardware here (no snes.h, no MMIO).
// See docs/plans/2026-06-27-13-snes-n-body-orbits.md.
#ifndef NBODY_H
#define NBODY_H

#include <stdint.h>

// ---------------------------------------------------------------------------
// Configuration

// Number of bodies (Sun + 2 planets).
#define NBODY_N          3

// Gravitational constant (G × mass_unit).  Tuned so Earth at r=30 px has a
// ≈130-frame period: a_c = GRAV_K*mass_sun/r² >> DT_SHIFT = v²/r.
// With GRAV_K=64, mass_sun=255, r=30: inv_r2=18; ax>>4=1.125 Q8.8 px/fr²;
// v_circ = sqrt(1.125*30)*256 ≈ 490 Q8.8 units; period ≈ 2π*30*256/490 ≈ 98 fr.
#define GRAV_K           64

// Softening ε²: added to r² to prevent 1/0 at close range.
#define GRAV_SOFT        16

// Velocity increment scale: force is divided by 2^DT_SHIFT before adding to
// velocity.  Acts as the timestep (larger DT_SHIFT → smaller steps → more stable
// but slower).  4 gives a good balance for a 60fps SNES demo.
#define DT_SHIFT         4

// Gate: number of integration steps folded into the CRC.  32 steps exercises
// 32 × 3 body-pairs × (2 __udivsi3 + 6 __mulsi3) = 96 divisions + 288 multiplies
// on the hot path.  Kept small so the gate finishes well within the 60-frame
// corpus settle window (on a par with pi_sim's ~676 operations).
#define NBODY_GATE_STEPS 32u

// ---------------------------------------------------------------------------
// Body struct

typedef struct {
    int16_t x, y;    // Q8.8 position on the 128×128 canvas (0 = left/top, 127×256 = right/bot)
    int16_t vx, vy;  // Q8.8 velocity in pixels/frame
    uint8_t mass;    // dimensionless mass (higher = more massive)
} NBody;

// ---------------------------------------------------------------------------
// Initial conditions

// Set b[] to the canonical starting configuration.
// Sun (mass 255) at canvas centre (64,64); bodies orbit on the same side of the
// screen so the viewer always sees the full orbit within the 128×128 box.
static void nbody_init(NBody *b) {
    // Body 0 — Sun (heavy, barely moves)
    b[0].x  = (int16_t)(64 << 8);
    b[0].y  = (int16_t)(64 << 8);
    b[0].vx = 0;
    b[0].vy = 0;
    b[0].mass = 255;

    // Body 1 — "Earth"  (r=30 to the right of Sun, CCW orbit on screen)
    // v_circ ≈ sqrt(inv_r2 * r) where inv_r2 = GRAV_K*mass_sun/r² >> DT_SHIFT
    //         = sqrt((64*255/900 >> 4) * 30) in Q8.8 space
    //         ≈ sqrt(1.125 * 30) * 256 ≈ 490
    b[1].x  = (int16_t)(94 << 8);  // 64 + 30 = 94
    b[1].y  = (int16_t)(64 << 8);
    b[1].vx = 0;
    b[1].vy = (int16_t)(-490);     // upward on screen (-y) = CCW
    b[1].mass = 1;

    // Body 2 — "Jupiter"  (r=50 to the left of Sun, same orbit sense)
    // inv_r2 at r=50: 64*255/2516 ≈ 6; ax >> 4 ≈ 0.375 Q8.8;
    // v_circ ≈ sqrt(0.375*50)*256 ≈ 439
    b[2].x  = (int16_t)(14 << 8);  // 64 - 50 = 14
    b[2].y  = (int16_t)(64 << 8);
    b[2].vx = 0;
    b[2].vy = (int16_t)(+439);     // downward on screen (+y) = CCW for body on the left
    b[2].mass = 3;
}

// ---------------------------------------------------------------------------
// Physics step (Symplectic Euler)

// Compute and accumulate the gravitational force between body bi and body bj.
// Takes explicit pointers for each body and accumulator slot to avoid
// variable-index array access (which creates complex live-ranges on 65816 RA).
// Hot arithmetic: 2 × __mulsi3 + 2 × __udivsi3 + 4 × 32-bit multiply (STRESSES #1-3).
static __attribute__((noinline)) void
nbody_force_pair(const NBody *bi, const NBody *bj,
                 int32_t *axi, int32_t *ayi,
                 int32_t *axj, int32_t *ayj) {
    // Pixel-space displacement (Q8.8 → integer pixel)
    int16_t dx = (int16_t)((bj->x - bi->x) >> 8);
    int16_t dy = (int16_t)((bj->y - bi->y) >> 8);

    // r² with softening — 16×16→32 multiply × 2 (STRESS #1)
    int32_t r2 = (int32_t)dx * dx + (int32_t)dy * dy + GRAV_SOFT;

    // Force magnitude: GRAV_K*m / r²  — __udivsi3 × 2 (STRESS #2)
    int32_t inv_r2_ij = (int32_t)GRAV_K * (int32_t)bj->mass / (uint32_t)r2;
    int32_t inv_r2_ji = (int32_t)GRAV_K * (int32_t)bi->mass / (uint32_t)r2;

    // Directional force components — 32-bit multiply × 4 (STRESS #3)
    *axi += (int32_t)dx * inv_r2_ij;
    *ayi += (int32_t)dy * inv_r2_ij;
    *axj -= (int32_t)dx * inv_r2_ji;
    *ayj -= (int32_t)dy * inv_r2_ji;
}

// One integration step: compute all pairwise forces and apply them.
// Called once per frame in the demo; called NBODY_GATE_STEPS times in the gate.
static __attribute__((noinline)) void nbody_step(NBody *b) {
    int32_t ax[NBODY_N] = {0, 0, 0};
    int32_t ay[NBODY_N] = {0, 0, 0};
    uint8_t i, j;

    for (i = 0; i < NBODY_N; i++)
        for (j = (uint8_t)(i + 1u); j < NBODY_N; j++)
            nbody_force_pair(&b[i], &b[j], &ax[i], &ay[i], &ax[j], &ay[j]);

    // Symplectic Euler update: v += a*dt; x += v  (dt absorbed into DT_SHIFT)
    for (i = 0; i < NBODY_N; i++) {
        b[i].vx = (int16_t)(b[i].vx + (int16_t)(ax[i] >> DT_SHIFT));
        b[i].vy = (int16_t)(b[i].vy + (int16_t)(ay[i] >> DT_SHIFT));
        b[i].x  = (int16_t)(b[i].x  + b[i].vx);
        b[i].y  = (int16_t)(b[i].y  + b[i].vy);
    }
}

// ---------------------------------------------------------------------------
// Differential gate CRC

// Run NBODY_GATE_STEPS integration steps from canonical ICs and fold each body's
// x, y, vx, vy into a 16-bit rotate-XOR hash.  Pure function; no side effects.
// host == default@SNES == +mos-a16@SNES == +mos-xy16@SNES is the differential.
static __attribute__((noinline)) uint16_t nbody_gate_crc(void) {
    NBody b[NBODY_N];
    nbody_init(b);
    uint16_t h = 0x13BD;
    uint16_t s;
    for (s = 0; s < (uint16_t)NBODY_GATE_STEPS; s++) {
        nbody_step(b);
        uint8_t i;
        for (i = 0; i < NBODY_N; i++) {
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].x;
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].y;
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].vx;
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].vy;
        }
    }
    return h;
}

#endif // NBODY_H
