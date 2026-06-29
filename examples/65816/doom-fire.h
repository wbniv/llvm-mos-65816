/* examples/65816/doom-fire.h — Doom-fire / heat-field, shared math header.
 * Pure C99/<stdint.h>; compiles identically on host (tools/doom-fire-sim.c) and SNES (+mos-a16).
 *
 * The classic PSX-Doom fire: a flat W*H heat grid whose bottom row is a constant max-heat source.
 * Every sweep, each interior cell inherits the cell BELOW it minus a random one-step decay, with a
 * random horizontal drift — so flames rise and flicker. Heat ∈ [0, FIRE_MAX] indexes a 16-colour
 * black→red→orange→yellow→white palette (doom-fire.c maps heat directly to a BG1 4bpp tile).
 *
 * Codegen stress (deliberately multiply-/divide-FREE in the inner loop):
 *   - array sweep    : the hot loop is `fire[src]` read + `fire[dst]` write over an 896-byte array
 *                      (flat-index, variable write offset) → `lda/sta (zp),y`-class traffic;
 *   - PRNG           : an xorshift16 per non-zero cell → native 16-bit `eor`/`asl`/`lsr` under one
 *                      rep/sep bracket under +mos-a16;
 *   - no __mulsi3/__udivmodsi4 in the per-cell loop (only two hoisted per-CALL 16-bit multiplies).
 *
 * Width discipline: every xorshift term is cast back to uint16_t so host (32-bit int) and target
 * (16-bit int) agree bit-for-bit. See docs/plans/2026-06-28-7-snes-doom-fire.md                  */
#ifndef DOOM_FIRE_H
#define DOOM_FIRE_H

#include <stdint.h>

/* Display grid (doom-fire.c): 32*8=256 px wide, 28*8=224 px tall — the full NTSC screen. */
#define FIRE_W    32
#define FIRE_H    28
#define FIRE_MAX  15   /* brightest heat = top palette index (16-colour 4bpp ramp) */

/* 16-bit xorshift PRNG — caller holds the state so host & target stay in lockstep. */
static inline uint16_t fire_rng(uint16_t *s) {
    uint16_t x = *s;
    x ^= (uint16_t)(x << 7);
    x ^= (uint16_t)(x >> 9);
    x ^= (uint16_t)(x << 8);
    return *s = x;
}

/* One Doom-fire propagation sweep over a flat (row-major) W*H heat grid (row 0 = top).
 * The bottom (source) row is read but never written, so the caller's max-heat source persists.
 * noinline: keeps the array-sweep loop intact (so the disasm gate can see it) and prevents LTO
 * from fusing it with the gate's copy/fold loop. */
static __attribute__((noinline)) void fire_step(uint8_t *fire, int16_t W, int16_t H, uint16_t *rng) {
    int16_t cells   = (int16_t)(W * H);              /* one 16-bit mul per CALL, not per cell */
    int16_t srcrow0 = (int16_t)((int16_t)(H - 1) * W); /* first index of the source row        */
    for (int16_t src = W; src < cells; src++) {
        uint8_t pixel = fire[src];
        if (pixel == 0) {
            fire[src - W] = 0;                       /* cool the cell directly above */
        } else {
            uint16_t r   = fire_rng(rng);
            int16_t  rnd = (int16_t)(r & 3u);        /* {0,1,2,3} */
            int16_t  dst = (int16_t)(src - W + 1 - rnd); /* row above, drift {+1,0,-1,-2} */
            if (dst >= 0 && dst < srcrow0)           /* guard: never write the source row / underflow */
                fire[dst] = (uint8_t)(pixel - (uint8_t)(rnd & 1u)); /* random 1-step decay */
        }
    }
}

/* ---- Differential gate -------------------------------------------------------------------- */
/* Small grid so corpus-a16 finishes well inside the harness frame budget; folds the FULL grid
 * after each step (rich hash) into a 16-bit rotate-XOR CRC. */
#define FIRE_GATE_W     16
#define FIRE_GATE_H     16
#define FIRE_GATE_STEPS 30

typedef struct {
    uint8_t fire[FIRE_GATE_W * FIRE_GATE_H];
} doomfire_gate_state;

static uint16_t doomfire_gate_crc(doomfire_gate_state *g) {
    uint16_t rng   = 0xF1A3u;
    int16_t  cells = (int16_t)(FIRE_GATE_W * FIRE_GATE_H);
    for (int16_t i = 0; i < cells; i++) g->fire[i] = 0;
    /* bottom row = source at FIRE_MAX */
    for (int16_t x = 0; x < FIRE_GATE_W; x++)
        g->fire[(FIRE_GATE_H - 1) * FIRE_GATE_W + x] = FIRE_MAX;
    uint16_t h = 0;
    for (int16_t s = 0; s < FIRE_GATE_STEPS; s++) {
        fire_step(g->fire, FIRE_GATE_W, FIRE_GATE_H, &rng);
        for (int16_t i = 0; i < cells; i++)
            h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)g->fire[i];
    }
    return h;
}

#endif /* DOOM_FIRE_H */
