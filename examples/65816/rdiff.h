/* examples/65816/rdiff.h — Gray-Scott reaction-diffusion, shared math header.
 * Pure C99/<stdint.h>; compiles on both host (tools/rdiff-sim.c) and SNES (+mos-a16).
 * Codegen stress: ≥4 × (int32_t * int16_t → int16_t) __mulsi3 per grid cell per step.
 * See docs/plans/2026-06-27-8-snes-rdiff-gray-scott.md                               */
#ifndef RDIFF_H
#define RDIFF_H

#include <stdint.h>

/* Simulation parameters (fixed-point: scale S=256, so S ≡ 1.0).
 * Du/Dv = 102/10 ≈ 10.2 — a high ratio is required for Turing-instability to fire on
 * the discrete grid.  F=14, k=16 gives a worm/coral morphology. */
#define GS_DU  102   /* Du*S ≈ 0.40*256  (activator diffusion — fast) */
#define GS_DV   10   /* Dv*S ≈ 0.04*256  (inhibitor diffusion — slow) */
#define GS_F    14   /* F*S  ≈ 0.055*256 (feed rate) */
#define GS_K    16   /* k*S  ≈ 0.063*256 (kill rate) */

/* Demo grid (used by rdiff.c; 32*8=256 px wide, 28*8=224 px tall) */
#define GS_W               32
#define GS_H               28
#define GS_STEPS_PER_FRAME  2   /* GS steps computed per 60 fps frame */

/* Gate sub-grid (small enough to finish before corpus-a16 times out) */
#define GS_GATE_W     8
#define GS_GATE_H     8
#define GS_GATE_STEPS 50

/* Gate state — caller allocates as a static to avoid soft-stack overflow on SNES */
typedef struct {
    int16_t u  [GS_GATE_H * GS_GATE_W];
    int16_t v  [GS_GATE_H * GS_GATE_W];
    int16_t nu [GS_GATE_H * GS_GATE_W];
    int16_t nv [GS_GATE_H * GS_GATE_W];
} rdiff_gate_state;

/* One Gray-Scott simulation step over a flat (row-major) W×H grid.
 * Reads (u,v), writes (nu,nv).  HOT PATH: 4 × __mulsi3 per cell
 * (uv=u*v, uvv=uv*v — two explicit var×var calls; dfu=DU*lu, dfv=DV*lv —
 *  constant×var, may expand to shifts+adds on some targets).
 * Values clamped to [0, 255] (S≡1.0). */
static void gs_step(int16_t *u, int16_t *v, int16_t *nu, int16_t *nv,
                    int16_t W, int16_t H) {
    int16_t i = 0;
    for (int16_t y = 0; y < H; y++) {
        for (int16_t x = 0; x < W; x++, i++) {
            int16_t uc = u[i];
            int16_t vc = v[i];
            /* 5-point Laplacian with toroidal wrap */
            int16_t xr = (int16_t)(x + 1 < W ? x + 1 : 0);
            int16_t xl = (int16_t)(x > 0     ? x - 1 : W - 1);
            int16_t yd = (int16_t)(y + 1 < H ? y + 1 : 0);
            int16_t yu = (int16_t)(y > 0     ? y - 1 : H - 1);
            int16_t lu = (int16_t)(u[y*W+xr] + u[y*W+xl] + u[yd*W+x] + u[yu*W+x])
                       - (int16_t)(4 * uc);
            int16_t lv = (int16_t)(v[y*W+xr] + v[y*W+xl] + v[yd*W+x] + v[yu*W+x])
                       - (int16_t)(4 * vc);
            /* u×v² reaction term — two explicit __mulsi3 calls (variable × variable) */
            int16_t uv  = (int16_t)((int32_t)uc * vc >> 8);
            int16_t uvv = (int16_t)((int32_t)uv  * vc >> 8);
            /* diffusion terms — two more variable-factor multiplies */
            int16_t dfu = (int16_t)((int32_t)GS_DU * lu >> 8);
            int16_t dfv = (int16_t)((int32_t)GS_DV * lv >> 8);
            /* feed: F*(1-u);  kill: (F+k)*v */
            int16_t fee = (int16_t)((int32_t)GS_F          * (int16_t)(255 - uc) >> 8);
            int16_t kil = (int16_t)((int32_t)(GS_F + GS_K) * vc >> 8);
            /* new concentrations, clamped to [0, 255] */
            int16_t nu_ = (int16_t)(uc + dfu - uvv + fee);
            int16_t nv_ = (int16_t)(vc + dfv + uvv - kil);
            nu[i] = nu_ < 0 ? 0 : nu_ > 255 ? 255 : nu_;
            nv[i] = nv_ < 0 ? 0 : nv_ > 255 ? 255 : nv_;
        }
    }
}

/* Gate hash: run GS_GATE_STEPS steps on an 8×8 grid seeded with a 2×2 central spot.
 * Folds V after EACH step into a 16-bit rotating-XOR CRC (cumulative — non-zero even
 * if the final state is trivial).  Pass a static rdiff_gate_state to avoid a 512-byte
 * soft-stack frame on SNES. */
static uint16_t rdiff_gate_crc(rdiff_gate_state *gs) {
    int16_t cells = (int16_t)(GS_GATE_H * GS_GATE_W);
    /* initialise: U=255 (≈1.0), V=0 everywhere */
    for (int16_t i = 0; i < cells; i++) { gs->u[i] = 255; gs->v[i] = 0; }
    /* seed 2×2 block at grid centre: U=128, V=128 */
    for (int16_t dy = 0; dy < 2; dy++) {
        for (int16_t dx = 0; dx < 2; dx++) {
            int16_t idx = (int16_t)((GS_GATE_H/2 + dy) * GS_GATE_W + (GS_GATE_W/2 + dx));
            gs->u[idx] = 128;
            gs->v[idx] = 128;
        }
    }
    /* simulate: fold V into CRC after every step (cumulative — captures the
     * full evolving transient, not just the potentially-trivial final state) */
    uint16_t h = 0;
    for (uint8_t s = 0; s < GS_GATE_STEPS; s++) {
        gs_step(gs->u, gs->v, gs->nu, gs->nv, GS_GATE_W, GS_GATE_H);
        for (int16_t i = 0; i < cells; i++) {
            gs->u[i] = gs->nu[i];
            gs->v[i] = gs->nv[i];
            h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)gs->v[i];
        }
    }
    return h;
}

#endif /* RDIFF_H */
