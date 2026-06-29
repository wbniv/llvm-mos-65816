/* examples/65816/rdiff.h — Gray-Scott reaction-diffusion, shared math header.
 * Pure C99/<stdint.h>; compiles on both host (tools/rdiff-sim.c) and SNES (+mos-a16).
 * Codegen stress: per cell per step, 2× int32 var×var (__mulsi3) for the u·v² reaction +
 * 4× int32 const×var for the diffusion/feed/kill terms — the 16-bit fixed-point makes every
 * product a genuine 32-bit multiply.
 *
 * 16-bit fixed-point (scale S=4096 ≡ 1.0): u,v ∈ [0,S] stored as uint16_t. The previous 8-bit
 * version (scale 256) was too coarse — the reaction couldn't resolve sub-unit structure, so the
 * field just flooded. At 12 bits the canonical Du=0.16/Dv=0.08, F≈0.037, k≈0.062 spot regime
 * forms a stable Turing pattern. Symmetry is broken by a scattered random seed (rdiff.c) — a
 * single symmetric seed only ever grows a symmetric ring.
 * See docs/plans/2026-06-27-8-snes-rdiff-gray-scott.md                                       */
#ifndef RDIFF_H
#define RDIFF_H

#include <stdint.h>

/* Fixed-point scale: S ≡ 1.0. */
#define GS_S    4096

/* Simulation parameters (Du,Dv scaled ×S; F,K are rates scaled ×S).
 *   Du/Dv = 0.16/0.08 (the activator diffuses twice as fast as the inhibitor)
 *   F = 0.0366 (feed), k = 0.062 (kill) — the classic stable-spot regime. */
#define GS_DU   655   /* 0.16 * 4096 */
#define GS_DV   328   /* 0.08 * 4096 */
#define GS_F    150   /* 0.0366 * 4096 (feed rate) */
#define GS_K    254   /* 0.062 * 4096  (kill rate; the kill term uses F+k) */

/* Demo grid (used by rdiff.c; 32*8=256 px wide, 24*8=192 px tall — 24 rows keeps the four
 * 16-bit double-buffers inside the 8 KB low-WRAM region; the display centres them with a 2-row
 * navy border top and bottom). */
#define GS_W               32
#define GS_H               24
#define GS_STEPS_PER_FRAME  1   /* GS steps computed per displayed frame (16-bit step is heavy) */
#define GS_ROW0             2   /* tilemap row the grid's top row maps to (centres 24 in 28) */

/* Gate sub-grid (small enough to finish before corpus-a16 times out) */
#define GS_GATE_W     8
#define GS_GATE_H     8
#define GS_GATE_STEPS  8   /* 8 steps; folded cumulatively into the CRC */

/* Gate state — caller allocates as a static to avoid soft-stack overflow on SNES.
 * uint16_t storage (values in [0,S]); 4 × 64 × 2 B = 512 B. */
typedef struct {
    uint16_t u  [GS_GATE_H * GS_GATE_W];
    uint16_t v  [GS_GATE_H * GS_GATE_W];
    uint16_t nu [GS_GATE_H * GS_GATE_W];
    uint16_t nv [GS_GATE_H * GS_GATE_W];
} rdiff_gate_state;

/* One Gray-Scott simulation step over a flat (row-major) W×H grid.
 * Reads (u,v), writes (nu,nv). Values clamped to [0,S].
 * noinline: prevents LTO from merging this loop with the caller's copy loop (the merged loop
 * would read nu/nv before all cells are written, making the result depend on uninitialised
 * memory — host-correct but wrong on SNES WRAM garbage). */
static __attribute__((noinline)) void gs_step(uint16_t *u, uint16_t *v, uint16_t *nu, uint16_t *nv,
                    int16_t W, int16_t H) {
    int16_t i = 0;
    for (int16_t y = 0; y < H; y++) {
        for (int16_t x = 0; x < W; x++, i++) {
            int32_t uc = (int32_t)u[i];
            int32_t vc = (int32_t)v[i];
            /* 5-point Laplacian with toroidal wrap */
            int16_t xr = (int16_t)(x + 1 < W ? x + 1 : 0);
            int16_t xl = (int16_t)(x > 0     ? x - 1 : W - 1);
            int16_t yd = (int16_t)(y + 1 < H ? y + 1 : 0);
            int16_t yu = (int16_t)(y > 0     ? y - 1 : H - 1);
            int32_t lu = (int32_t)u[y*W+xr] + (int32_t)u[y*W+xl]
                       + (int32_t)u[yd*W+x] + (int32_t)u[yu*W+x] - (int32_t)(4 * uc);
            int32_t lv = (int32_t)v[y*W+xr] + (int32_t)v[y*W+xl]
                       + (int32_t)v[yd*W+x] + (int32_t)v[yu*W+x] - (int32_t)(4 * vc);
            /* u·v² reaction term — two int32 var×var multiplies (__mulsi3) */
            int32_t uv  = (uc * vc) >> 12;
            int32_t uvv = (uv * vc) >> 12;
            /* diffusion + feed + kill — four int32 const×var multiplies */
            int32_t dfu = (GS_DU * lu) >> 12;
            int32_t dfv = (GS_DV * lv) >> 12;
            int32_t fee = (GS_F          * (GS_S - uc)) >> 12;
            int32_t kil = ((GS_F + GS_K) * vc)          >> 12;
            /* new concentrations, clamped to [0, S] */
            int32_t nu_ = uc + dfu - uvv + fee;
            int32_t nv_ = vc + dfv + uvv - kil;
            nu[i] = (uint16_t)(nu_ < 0 ? 0 : nu_ > GS_S ? GS_S : nu_);
            nv[i] = (uint16_t)(nv_ < 0 ? 0 : nv_ > GS_S ? GS_S : nv_);
        }
    }
}

/* Gate hash: run GS_GATE_STEPS steps on an 8×8 grid seeded with a 2×2 central spot.
 * Folds V (scaled to a byte) after EACH step into a 16-bit rotating-XOR CRC. */
static uint16_t rdiff_gate_crc(rdiff_gate_state *gs) {
    uint8_t cells = (uint8_t)(GS_GATE_H * GS_GATE_W);
    /* initialise: U=S (≈1.0), V=0 everywhere */
    for (uint8_t i = 0; i < cells; i++) { gs->u[i] = GS_S; gs->v[i] = 0; }
    /* seed 2×2 block at grid centre: U=S/2, V=S/4 */
    for (uint8_t dy = 0; dy < 2; dy++) {
        for (uint8_t dx = 0; dx < 2; dx++) {
            uint8_t idx = (uint8_t)((GS_GATE_H/2 + dy) * GS_GATE_W + (GS_GATE_W/2 + dx));
            gs->u[idx] = GS_S/2;
            gs->v[idx] = GS_S/4;
        }
    }
    uint16_t h = 0;
    for (uint8_t s = 0; s < GS_GATE_STEPS; s++) {
        gs_step(gs->u, gs->v, gs->nu, gs->nv, GS_GATE_W, GS_GATE_H);
        for (uint8_t i = 0; i < cells; i++) {
            gs->u[i] = gs->nu[i];
            gs->v[i] = gs->nv[i];
            h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)(gs->v[i] >> 4);
        }
    }
    return h;
}

#endif /* RDIFF_H */
