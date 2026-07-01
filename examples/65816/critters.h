// Shared, PURE protothread critter swarm — host-linkable, no hardware.  Demo #51.
//
// The codegen corner: **resumable functions (coroutines / protothreads)** — each critter is a function
// that YIELDS (returns) mid-script and RESUMES where it left off, via a saved continuation index (`lc`)
// driving a `switch` whose case labels sit INSIDE loops.  Local loop state (the step counter) lives in
// the struct so it survives re-entry.  This combines saved case-index re-entry with mid-loop case labels
// (irreducible control flow, à la Duff's device) plus cross-call state preservation — a coroutine shape
// no other demo runs.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - positions/velocities are int16_t, counters uint8_t; the resume is deterministic so host and target
//     produce identical trajectories; the fold masks to uint16_t.
// See docs/plans/2026-06-30-51-snes-critters.md.
#ifndef CRITTERS_H
#define CRITTERS_H

#include <stdint.h>

#define NCRIT 24u
#define WALK  12u          // steps per leg of the patrol

typedef struct {
    uint8_t lc;            // protothread continuation (saved case index)
    int16_t x, y;          // position
    int16_t vx, vy;        // velocity
    uint8_t timer;         // per-leg step counter (survives re-entry -> the "local" the coroutine keeps)
    uint8_t color;
} Critter;

// Resume the critter's scripted patrol: walk one leg right, yield each step; then a leg down; then
// reverse and repeat.  The `case` labels land inside the `for` loops (mid-loop re-entry).  noinline
// keeps the resumable-function call + on-entry switch-dispatch real (no inlining folds it away).
__attribute__((noinline))
static void critter_step(Critter *c) {
    switch (c->lc) {
        case 0:
            for (;;) {
                for (c->timer = 0; c->timer < WALK; c->timer++) {
                    c->x = (int16_t)(c->x + c->vx);
                    c->lc = 1; return; case 1:; /* yield, resume here */
                }
                for (c->timer = 0; c->timer < WALK; c->timer++) {
                    c->y = (int16_t)(c->y + c->vy);
                    c->lc = 2; return; case 2:;
                }
                c->vx = (int16_t)(-c->vx);
                c->vy = (int16_t)(-c->vy);       // reverse -> box patrol
            }
    }
}

static void critters_init(Critter *cr) {
    for (uint8_t i = 0; i < NCRIT; i++) {
        cr[i].lc = 0u;
        cr[i].x = (int16_t)(8 + (i % 6u) * 18u);
        cr[i].y = (int16_t)(8 + (i / 6u) * 26u);
        cr[i].vx = (int16_t)(1 + (i & 1u));
        cr[i].vy = (int16_t)(1 + ((i >> 1) & 1u));
        cr[i].timer = 0u;
        cr[i].color = (uint8_t)(1u + (i % 3u));
    }
}

// ---------------------------------------------------------------------------------------------
// Differential gate: step the swarm GATE_N frames, folding every critter's position each frame.

static inline uint16_t cr_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 120u
#endif

static uint16_t critters_gate_crc(void) {
    static Critter cr[NCRIT];
    critters_init(cr);
    uint16_t h = 0;
    for (uint16_t f = 0; f < (uint16_t)GATE_N; f++) {
        for (uint8_t i = 0; i < NCRIT; i++) {
            critter_step(&cr[i]);                // resume each protothread one step
            h = cr_fold(h, (uint16_t)((uint16_t)cr[i].x * 3u + (uint16_t)cr[i].y + cr[i].lc));
        }
    }
    return h;
}

#endif /* CRITTERS_H */
