// Shared, PURE Buddhabrot math — the single source of truth for both the headless far-grid
// kernel/host oracle (examples/65816/k_buddha_far.c) and the on-screen renderer
// (examples/snes/buddha.c). Like mandel.h / hopalong.h, this is the code under test for the
// +mos-a16 differential: the SAME body runs on the host oracle (int = 32) and the 65816 target
// (int = 16), so host == target bit-for-bit by construction. Every narrowing is an explicit
// fixed-width cast and every product is forced through int32_t — DO NOT "simplify" a cast away,
// it is load-bearing for the gate.
//
// The Buddhabrot: sample random complex c (xorshift16 PRNG); iterate z <- z^2 + c from z = 0; for
// the c that ESCAPE (|z|^2 > 4 within BUD_MAXITER), REPLAY the orbit and increment a per-pixel hit
// counter at every visited (zr,zi). Over many escaping orbits the accumulated density resolves into
// the smoke-like silhouette. Two passes per sample:
//   Pass 1  bud_escape_k()  — does c escape, and after how many steps? NO grid pointer live.
//   Pass 2  *_plot (BUD_DEFINE_PLOT) — replay k steps, far read-modify-write the density grid.
// Splitting them bounds the +mos-a16 register pressure: the far (32-bit) pointer is live ONLY in
// the replay, never alongside pass 1's complex-iteration intermediates (handoff §4 far-pressure).
//
// The density grid is a far (high-WRAM) buffer on target and a near array on the host —
// BUD_DEFINE_{CLEAR,PLOT,ACCUM,HASH} stamp the identical loop body over a pointer qualifier (the
// hopalong.h HOP_DEFINE_* idiom), so the host needs no address_space(2) and the two agree exactly.
//
// NO hardware here (no snes.h, no MMIO) — host-linkable. See
// docs/plans/2026-06-28-4-snes-buddhabrot.md.
#ifndef BUDDHA_H
#define BUDDHA_H

#include <stdint.h>

// --------------------------------------------------------------------------------------------
// Fixed point + window. Q5.10 (1.0 == 1024), matching julia.h / mandel.h.

#define BUD_Q       10
#define BUD_ONE     (1 << BUD_Q)            // 1024
#define BUD_ESCAPE  (4 << BUD_Q)            // |z|^2 > 4.0 in Q5.10 == 4096

// Square density grid edge (128 == 16 KiB at $7E2000, 1:1 with the Mode 7 display).
#ifndef BUD_GRID
#define BUD_GRID 128
#endif
#define BUD_CENTER (BUD_GRID / 2)

// Sampling AND coordinate-map window is the POWER-OF-TWO box [-2,2]^2 (Q5.10 [-2048, 2047]) so the
// orbit-point -> pixel map is a pure arithmetic shift (no per-point divide; the per-sample budget is
// already ~2x the iteration cost). Width 4.0*1024 = 4096 over BUD_GRID px -> shift = log2(4096/128).
#if   BUD_GRID == 128
#define BUD_MAP_SHIFT 5                     // 4096 / 128 == 32 == 1<<5
#elif BUD_GRID == 256
#define BUD_MAP_SHIFT 4                     // 4096 / 256 == 16 == 1<<4
#else
#error "buddha.h: define BUD_MAP_SHIFT for this BUD_GRID"
#endif

// Total cells as a uint16_t (16384 for the 128 grid). The (uint32_t) cast keeps the product from
// overflowing 16-bit int at compile time; the do/while hash/clear loops run until ++i wraps.
#define BUD_NCELLS ((uint16_t)((uint32_t)BUD_GRID * (uint32_t)BUD_GRID))

// Escape-time cap + the minimum orbit length we record. BUD_MINITER discards the instant-escapers
// (only z_0 = 0 plotted) that would otherwise smear noise onto the centre; the boundary orbits with
// large k draw the filaments. (Tuned in the plan's verification pass.)
#ifndef BUD_MAXITER
#define BUD_MAXITER 32u                     // escapers (and thus the image) barely change vs 64, but
#endif                                      // interior samples run the full cap, so 32 is ~1/3 cheaper
#ifndef BUD_MINITER
#define BUD_MINITER 4u
#endif

// Sampling window for c — the Mandelbrot region the set actually occupies (Q5.10), NOT the full
// [-2,2]^2 map box: concentrating samples where escaping-but-slow orbits live spends far fewer wild
// instant-escapers, so the figure resolves with richer density (better palette gradients) per sample.
// Real ∈ [-2.0, +0.6], imag ∈ [-1.3, +1.3] (symmetric about the real axis ⇒ the density, and thus
// the image, is top-bottom symmetric — a free correctness check). The map box stays [-2,2]^2 so the
// escaping orbit tails frame nicely inside the grid with margin.
#define BUD_CRE_LO (-2048)                  // -2.0  * 1024
#define BUD_CRE_W   2662                    //  2.6  * 1024  (real  window width)
#define BUD_CIM_LO (-1331)                  // -1.3  * 1024
#define BUD_CIM_W   2662                    //  2.6  * 1024  (imag  window width)

// Force the pressure-prone callees out of line on the far path (handoff §4): a function holding the
// complex intermediates OR a 32-bit far pointer live must not be inlined into one giant main(), or
// the combined +mos-a16 pressure derails at runtime (a clean -verify build that nonetheless crashes).
#ifndef BUD_FN
#define BUD_FN __attribute__((noinline)) static
#endif

// --------------------------------------------------------------------------------------------
// PRNG — xorshift16 (the 3-tap used across invaders_logic.h / spigot.c). Deterministic ⇒ host==target.

// Fixed PRNG seed — the on-screen ROM and the host oracle must share it so the grid after K_GATE
// samples is bit-identical (the gate proof). Shared here, not in either .c, so they can't drift.
#ifndef BUD_SEED
#define BUD_SEED 0xC0DEu
#endif

typedef struct { uint16_t s; } bud_rng;

static inline void bud_rng_init(bud_rng *r, uint16_t seed) { r->s = seed ? seed : 0xBEEFu; }

static inline uint16_t bud_rng16(bud_rng *r) {
  uint16_t x = r->s;
  x ^= (uint16_t)(x << 7);
  x ^= (uint16_t)(x >> 9);
  x ^= (uint16_t)(x << 8);
  r->s = x;
  return x;
}

// One random complex coordinate in [lo, lo+w) Q5.10: scale the 16-bit word (0..65535) by the window
// width via an UNSIGNED 32-bit multiply (__umulsi3) then >> 16 -> [0, w). Every cast is explicit so
// the 32-bit product and shift fold bit-identically on host (int=32) and target (int=16).
static inline int16_t bud_sample_win(bud_rng *r, int16_t lo, int16_t w) {
  uint16_t u = bud_rng16(r);
  return (int16_t)((int32_t)lo + (int32_t)(((uint32_t)u * (uint32_t)(uint16_t)w) >> 16));
}
static inline int16_t bud_sample_re(bud_rng *r) { return bud_sample_win(r, BUD_CRE_LO, BUD_CRE_W); }
static inline int16_t bud_sample_im(bud_rng *r) { return bud_sample_win(r, BUD_CIM_LO, BUD_CIM_W); }

// --------------------------------------------------------------------------------------------
// Pass 1 — escape test. Returns the step index k at which z_k escaped (|z_k|^2 > 4), i.e. the orbit
// visited z_0..z_{k-1} inside the disc; returns 0 if c never escaped within BUD_MAXITER (interior —
// never recorded). NO grid pointer live: pure complex iteration (three 16x16->32 multiplies/step,
// the julia_cell hot path). noinline keeps its 16-bit live set out of the accumulator's a16 budget.
BUD_FN uint8_t bud_escape_k(int16_t cr, int16_t ci, uint8_t maxiter) {
  int16_t zr = 0, zi = 0;
  for (uint8_t k = 0; k < maxiter; k++) {
    int32_t zr2 = ((int32_t)zr * zr) >> BUD_Q;            // __mulsi3
    int32_t zi2 = ((int32_t)zi * zi) >> BUD_Q;            // __mulsi3
    if (zr2 + zi2 > BUD_ESCAPE) return k;                 // escaped at z_k (k points were inside)
    int16_t nzr = (int16_t)(zr2 - zi2 + cr);
    zi = (int16_t)(2 * (((int32_t)zr * zi) >> BUD_Q) + ci);   // __mulsi3
    zr = nzr;
  }
  return 0;                                               // interior — not part of the Buddhabrot
}

// Map a Q5.10 orbit coordinate to a grid pixel: a pure arithmetic shift + centre offset (folds
// identically host/target). Points outside the grid (the escaping tail beyond [-2,2]) are dropped by
// the caller's unsigned compare — a smear-free border.
static inline int16_t bud_map(int16_t v) {
  return (int16_t)((int16_t)(v >> BUD_MAP_SHIFT) + BUD_CENTER);
}

// --------------------------------------------------------------------------------------------
// Pass 2 — orbit replay + density scatter. Stamp `NAME(QUAL uint8_t *grid, int16_t cr, int16_t ci,
// uint8_t k)`: re-iterate the orbit k steps (identical math to bud_escape_k, so the same points), and
// for each NEW point z_1..z_k increment the saturating hit counter (far RMW on target: lda [dp] /
// compare / inc / sta [dp]). z_0 = 0 is intentionally NOT plotted (it maps to the centre for every
// escaper, an over-bright artifact). The orientation maps zi -> x, zr -> y so the set stands upright
// (the canonical Buddha pose); the density is symmetric about the real axis.
#define BUD_DEFINE_PLOT(NAME, QUAL)                                              \
  BUD_FN void NAME(QUAL uint8_t *grid, int16_t cr, int16_t ci, uint8_t k) {      \
    int16_t zr = 0, zi = 0;                                                      \
    for (uint8_t s = 0; s < k; s++) {                                            \
      int32_t zr2 = ((int32_t)zr * zr) >> BUD_Q;                                 \
      int32_t zi2 = ((int32_t)zi * zi) >> BUD_Q;                                 \
      int16_t nzr = (int16_t)(zr2 - zi2 + cr);                                   \
      zi = (int16_t)(2 * (((int32_t)zr * zi) >> BUD_Q) + ci);                    \
      zr = nzr;                                                                  \
      int16_t px = bud_map(zi), py = bud_map(zr);                                \
      if ((uint16_t)px < (uint16_t)BUD_GRID &&                                   \
          (uint16_t)py < (uint16_t)BUD_GRID) {                                   \
        uint16_t idx = (uint16_t)((unsigned)py * BUD_GRID + (unsigned)px);       \
        uint8_t hv = grid[idx];                       /* FAR LOAD */             \
        if (hv != 255) grid[idx] = (uint8_t)(hv + 1);  /* FAR STORE, saturating */\
      }                                                                          \
    }                                                                            \
  }

// --------------------------------------------------------------------------------------------
// Driver — stamp `NAME(QUAL uint8_t *grid, NAME_plot, bud_rng *rng, uint16_t nsamples)`. Draws
// nsamples random c (CONTINUING the PRNG state, so a from-scratch render and a chunked live bloom
// produce the same grid), escape-tests each, and replays the escaping ones into the grid. The far
// pointer is live across the loop but only PASSED THROUGH to the noinline plot — the heavy complex
// intermediates stay inside the two callees. PLOTFN is the BUD_DEFINE_PLOT'd function of matching QUAL.
#define BUD_DEFINE_ACCUM(NAME, QUAL, PLOTFN)                                     \
  BUD_FN void NAME(QUAL uint8_t *grid, bud_rng *rng, uint16_t nsamples) {        \
    for (uint16_t i = 0; i < nsamples; i++) {                                    \
      int16_t cr = bud_sample_re(rng);                                          \
      int16_t ci = bud_sample_im(rng);                                          \
      uint8_t k = bud_escape_k(cr, ci, (uint8_t)BUD_MAXITER);                    \
      if (k >= (uint8_t)BUD_MINITER) PLOTFN(grid, cr, ci, k);                    \
    }                                                                            \
  }

// --------------------------------------------------------------------------------------------
// Stamp `NAME(QUAL uint8_t *grid)` — zero the whole grid. The far grid is NOT linker-zeroed (it's a
// runtime far pointer, not .bss) and bsnes randomises WRAM, so the target MUST clear it before
// accumulating. VOLATILE store (the `g` alias) is load-bearing on the far path: a non-volatile
// constant fill of an address_space(2) buffer coalesces into the NEAR __memset libcall, which ignores
// the 24-bit bank byte and writes $00:xxxx (MMIO/open-bus) instead of $7E:xxxx — a silent far-pointer
// miscompile (hopalong.h:154; docs/320-far-memset-miscompile.md). A volatile store is never coalesced.
#define BUD_DEFINE_CLEAR(NAME, QUAL)                                            \
  BUD_FN void NAME(QUAL uint8_t *grid) {                                        \
    volatile QUAL uint8_t *g = grid;                                            \
    uint16_t i = 0;                                                             \
    do { g[i] = 0; } while (++i != BUD_NCELLS);                                 \
  }

// Stamp `NAME(QUAL uint8_t *grid) -> uint16_t` — rotate-xor rolling hash over the whole grid (the
// img_hash16 / hopalong grid_hash idiom): far loads on target. The proof channel — host oracle hash
// == target hash over the same deterministic K_GATE accumulation proves every far RMW carried.
#define BUD_DEFINE_HASH(NAME, QUAL)                                             \
  BUD_FN uint16_t NAME(QUAL uint8_t *grid) {                                    \
    uint16_t h = 0, i = 0;                                                      \
    do {                                                                        \
      unsigned hi = ((unsigned)h >> 15) & 1u;                                  \
      h = (uint16_t)((((unsigned)h << 1) | hi) ^ (unsigned)grid[i]);            \
    } while (++i != BUD_NCELLS);                                                \
    return h;                                                                   \
  }

#endif /* BUDDHA_H */
