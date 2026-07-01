// Shared, PURE free-list pool allocator — host-linkable, no hardware.  Demo #41.
//
// The codegen corner: a **manual free-list pool allocator** — particles are allocated on spawn and
// freed on death, recycling fixed slots through a singly-linked LIFO free list threaded THROUGH the
// slots themselves (`next` index).  Distinct from #31's append-only bump pool (which only ever grows
// then resets): here individual slots are unlinked (alloc) and re-linked (free) every frame, so the
// hot path is pointer/index recycling — `head = slot[head].next` on alloc, `slot[i].next = head;
// head = i` on free.  A particle fountain drives it: continuous births (pop) and deaths (push).
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - slot indices are uint16_t (POOL_NULL = 0xFFFF sentinel); particle fields are int16_t
//   - every multiply/add in the fold is masked back to uint16_t so 32-bit host == 16-bit target
// See docs/plans/2026-06-30-41-snes-poolfx.md.
#ifndef POOLFX_H
#define POOLFX_H

#include <stdint.h>

#define POOL_N     48u        // number of recyclable slots
#define POOL_NULL  0xFFFFu    // free-list end sentinel
#define PFX_FX     4          // Q4 fixed point (1 px == 16 units)
#define PFX_GRAV   3          // gravity per frame (Q4)
#define PFX_SPAWN  3u         // births attempted per frame

typedef struct {
    int16_t  x, y;    // position (Q4)
    int16_t  vx, vy;  // velocity (Q4)
    int16_t  life;    // frames remaining; 0 == free/dead (also the liveness flag)
    uint16_t next;    // free-list link when free (index of next free slot) or POOL_NULL
} Particle;

typedef struct {
    Particle p[POOL_N];
    uint16_t free_head;   // index of first free slot, POOL_NULL when exhausted
    uint16_t live;        // live-slot count (bookkeeping)
} Pool;

// Thread every slot onto the free list: p[i].next = i+1, last -> NULL; nothing live.
static inline void pool_init(Pool *pl) {
    for (uint16_t i = 0; i < POOL_N; i++) {
        pl->p[i].next = (uint16_t)(i + 1u);
        pl->p[i].life = 0;
    }
    pl->p[POOL_N - 1u].next = POOL_NULL;
    pl->free_head = 0u;
    pl->live = 0u;
}

// Pop a slot off the free list (unlink the head).  Returns its index, or POOL_NULL if exhausted.
static inline uint16_t pool_alloc(Pool *pl) {
    uint16_t i = pl->free_head;
    if (i == POOL_NULL) return POOL_NULL;
    pl->free_head = pl->p[i].next;    // head = slot[head].next
    pl->live++;
    return i;
}

// Push slot i back onto the free list (re-link as the new head).
static inline void pool_free(Pool *pl, uint16_t i) {
    pl->p[i].next = pl->free_head;    // slot[i].next = head; head = i
    pl->free_head = i;
    pl->p[i].life = 0;
    pl->live--;
}

// ---------------------------------------------------------------------------------------------
// Fountain simulation over the pool.

static uint16_t pfx_rng = 0xACE1u;
static inline uint16_t pfx_rand(void) {
    pfx_rng ^= (uint16_t)(pfx_rng << 7);
    pfx_rng ^= (uint16_t)(pfx_rng >> 9);
    pfx_rng ^= (uint16_t)(pfx_rng << 8);
    return pfx_rng;
}

// Emit one particle from the fountain nozzle (centre-bottom), if a slot is free.
static inline void fountain_spawn(Pool *pl) {
    uint16_t i = pool_alloc(pl);
    if (i == POOL_NULL) return;                       // pool full — birth dropped (realistic)
    Particle *q = &pl->p[i];
    q->x  = (int16_t)(64 << PFX_FX);                  // nozzle at (64, 120)
    q->y  = (int16_t)(120 << PFX_FX);
    q->vx = (int16_t)((int16_t)(pfx_rand() & 0x3Fu) - 32);          // horizontal spread -32..31
    q->vy = (int16_t)(-(int16_t)((pfx_rand() & 0x1Fu) + 40u));      // upward thrust -40..-71
    q->life = (int16_t)((pfx_rand() & 0x1Fu) + 24u);               // 24..55 frames
}

// Advance the whole fountain one frame: spawn, integrate, free the dead.
static inline void fountain_step(Pool *pl) {
    for (uint8_t s = 0; s < PFX_SPAWN; s++) fountain_spawn(pl);
    for (uint16_t i = 0; i < POOL_N; i++) {
        Particle *q = &pl->p[i];
        if (q->life <= 0) continue;                   // free slot — skip
        q->vy = (int16_t)(q->vy + PFX_GRAV);          // gravity
        q->x  = (int16_t)(q->x + q->vx);
        q->y  = (int16_t)(q->y + q->vy);
        q->life = (int16_t)(q->life - 1);
        if (q->life <= 0 || q->y >= (int16_t)(128 << PFX_FX))
            pool_free(pl, i);                         // death -> recycle the slot
    }
}

// ---------------------------------------------------------------------------------------------
// Differential gate: run the fountain GATE_N frames, folding the full pool state each frame.

static inline uint16_t poolfx_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 100u
#endif

static uint16_t poolfx_gate_crc(void) {
    static Pool pl;                    // static: keep the 580-byte pool off the soft stack
    pool_init(&pl);
    pfx_rng = 0xACE1u;                 // deterministic seed
    uint16_t h = 0;
    for (uint16_t f = 0; f < (uint16_t)GATE_N; f++) {
        fountain_step(&pl);
        uint16_t s = (uint16_t)(pl.free_head ^ (uint16_t)(pl.live << 3));
        for (uint16_t i = 0; i < POOL_N; i++)
            s = (uint16_t)(s + (uint16_t)((uint16_t)pl.p[i].x * 3u) + (uint16_t)pl.p[i].y
                             + (uint16_t)pl.p[i].next);
        h = poolfx_fold(h, s);
    }
    return h;
}

#endif /* POOLFX_H */
