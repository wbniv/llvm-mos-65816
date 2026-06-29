// Shared, PURE maze generate + solve — host-linkable, no hardware.  #18 of the compiler
// stress-test demo battery.
//
//   GENERATE: a randomized recursive-backtracker DFS carve (maze_carve) — genuine recursion,
//     so the soft-stack / frame-ABI codegen is exercised exactly the way fork patch 0003's
//     F4 TYX/TXY dead-flag crash and the soft-stack Ac16-spill family were found (a recursive
//     +mos-a16 callee). Depth is O(path length); the grid is sized so the worst-case depth
//     stays well inside the SNES soft-stack room (link.ld: stack grows down from $2000, bss up
//     from $0200 — ~5 KB once the demo's bss is placed). See the plan's depth measurement.
//
//   SOLVE: A* shortest path over the carved grid with an INDEXED binary min-heap priority
//     queue (decrease-key via an hpos[] position map) + a Manhattan-distance heuristic. The
//     heap sift-up/sift-down (array index << 1 / >> 1, struct-ish parallel arrays, the pos-map
//     write-back on every swap) is the heap/queue/array data-structure stress.
//
// All arithmetic is uint8_t/uint16_t (indices ≤ MAZE_W*MAZE_H-1 < 256 for the default size,
// Manhattan ≤ MAZE_W+MAZE_H, g-scores ≤ MAZE_N) so the SAME source folds to the SAME CRC on
// both host (int=32) and 65816 target (int=16) — no 32-bit libcalls; the codegen corner under
// test is recursion + branchy heap/array code under +mos-a16, not multiply/divide.
//
// No hardware here (no snes.h, no MMIO). See docs/plans/2026-06-28-18-snes-maze-generate-solve.md.
#ifndef MAZE_H
#define MAZE_H

#include <stdint.h>

// ---------------------------------------------------------------------------------------------
// Configuration

// Grid dimensions in cells. MAZE_W is a POWER OF TWO so every cell→(x,y) decode is a shift/mask
// (cell>>MAZE_WSH / cell&MAZE_WMASK), never a __udivmodhi4 libcall — faster hot loops on a
// machine with no hardware divide. 16x15 = 240 cells → a 128x120-px tiled field (8 px/cell),
// worst-case recursive-carve depth well inside the soft-stack budget (measured: see the plan).
// Overridable so the gate and the on-screen demo share one size.
#ifndef MAZE_W
#define MAZE_W 16u
#endif
#define MAZE_WSH   4u            // log2(MAZE_W)
#define MAZE_WMASK 15u           // MAZE_W - 1
#ifndef MAZE_H_CELLS
#define MAZE_H_CELLS 15u
#endif
#define MAZE_N ((uint16_t)(MAZE_W * MAZE_H_CELLS))

// Wall bits (a cell keeps a wall on each side that has not been carved through).
#define WALL_N 1u
#define WALL_E 2u
#define WALL_S 4u
#define WALL_W 8u
#define WALL_ALL 0x0Fu

// A* node state.
#define ST_UNSEEN 0u
#define ST_OPEN   1u
#define ST_CLOSED 2u

// ---------------------------------------------------------------------------------------------
// State — all bank-0 NEAR (no far pointers → builds default + a16 + xy16).

typedef struct {
    uint8_t  wall[MAZE_N];   // per-cell wall bitmask (carve clears bits on both sides)
    uint8_t  vis[MAZE_N];    // carve: visited flag / solve: reused as node state (ST_*)
    uint16_t g[MAZE_N];      // A* cost-so-far (0xFFFF = +inf)
    uint8_t  came[MAZE_N];   // A* direction the cell was reached FROM (0..3), 0xFF = none
    uint16_t heap[MAZE_N];   // indexed binary min-heap of cell ids (size ≤ MAZE_N)
    uint16_t hpos[MAZE_N];   // hpos[cell] = its index in heap[], 0xFFFF = not in heap
    uint16_t hn;             // heap element count
    uint16_t rng;            // xorshift16 state
    uint16_t expanded;       // A* nodes popped/closed (proof counter)
    uint16_t pushes;         // heap pushes (proof counter)
    uint16_t path_len;       // shortest-path length (edges); 0xFFFF = unreachable
} maze_t;

// Direction vectors: 0=N 1=E 2=S 3=W.  opposite(d) = (d+2)&3.
static const int8_t MAZE_DX[4] = { 0, 1, 0, -1 };
static const int8_t MAZE_DY[4] = { -1, 0, 1, 0 };
static const uint8_t MAZE_WBIT[4] = { WALL_N, WALL_E, WALL_S, WALL_W };

static inline uint16_t maze_idx(uint8_t x, uint8_t y) {
    return (uint16_t)(((uint16_t)y << MAZE_WSH) + x);
}

// ---------------------------------------------------------------------------------------------
// RNG — xorshift16 (same 3-tap used across the battery).

static inline uint16_t maze_rng16(maze_t *m) {
    uint16_t x = m->rng;
    x ^= (uint16_t)(x << 7);
    x ^= (uint16_t)(x >> 9);
    x ^= (uint16_t)(x << 8);
    m->rng = x;
    return x;
}

// ---------------------------------------------------------------------------------------------
// GENERATE — recursive-division (genuine recursion: a function calling itself, so the soft-stack
// frame ABI + JSR/RTS codegen is exercised exactly like the recursive cases that surfaced fork
// patch 0003's F4 crash). Chosen over a recursive-backtracker DFS because the 65816 return-address
// stack is the 256-byte hardware page $0100-$01FF and llvm-mos keeps ~4 callee-saved bytes live
// across the self-call (~6 B/level) — a DFS's O(N) depth (≈190 for a 16×15 grid) blows the HW
// stack and corrupts memory, while recursive division's centre-biased split is ~log depth (≤16
// here) and fits with wide margin. See the plan's hardware-stack-ceiling measurement.
//
// Start from an open room (only border walls), then recursively bisect each sub-rectangle with a
// wall that has one random gap; every added wall keeps a gap, so the maze stays fully connected
// (A* always finds a start→goal path).

// Split offset within a region of size s (≥2): centre-biased, returned in [1, s-1]. The centre
// bias keeps the recursion shallow (bounded depth) regardless of the RNG.
static inline uint8_t maze_split(maze_t *m, uint8_t s) {
    uint8_t half = (uint8_t)(s >> 1); if (half == 0u) half = 1u;
    uint8_t off = (uint8_t)((uint8_t)(s >> 2) + (uint8_t)(maze_rng16(m) % half));
    if (off < 1u) off = 1u;
    if (off > (uint8_t)(s - 1u)) off = (uint8_t)(s - 1u);
    return off;
}

__attribute__((noinline))
static void maze_divide(maze_t *m, uint8_t x0, uint8_t y0, uint8_t w, uint8_t h) {
    if (w <= 1u || h <= 1u) return;
    if (w >= h) {
        uint8_t wx  = (uint8_t)(x0 + maze_split(m, w));        // wall between cols wx-1 | wx
        uint8_t gap = (uint8_t)(y0 + (maze_rng16(m) % h));     // single passage through it
        for (uint8_t y = y0; y < (uint8_t)(y0 + h); y++) {
            if (y == gap) continue;
            m->wall[maze_idx((uint8_t)(wx - 1u), y)] |= WALL_E;
            m->wall[maze_idx(wx, y)]                 |= WALL_W;
        }
        maze_divide(m, x0, y0, (uint8_t)(wx - x0), h);
        maze_divide(m, wx, y0, (uint8_t)(x0 + w - wx), h);
    } else {
        uint8_t wy  = (uint8_t)(y0 + maze_split(m, h));        // wall between rows wy-1 | wy
        uint8_t gap = (uint8_t)(x0 + (maze_rng16(m) % w));
        for (uint8_t x = x0; x < (uint8_t)(x0 + w); x++) {
            if (x == gap) continue;
            m->wall[maze_idx(x, (uint8_t)(wy - 1u))] |= WALL_S;
            m->wall[maze_idx(x, wy)]                 |= WALL_N;
        }
        maze_divide(m, x0, y0, w, (uint8_t)(wy - y0));
        maze_divide(m, x0, wy, w, (uint8_t)(y0 + h - wy));
    }
}

static void maze_generate(maze_t *m, uint16_t seed) {
    m->rng = seed ? seed : 0xACE1u;
    // Open room: clear interior walls, keep the outer border.
    for (uint8_t y = 0u; y < MAZE_H_CELLS; y++)
        for (uint8_t x = 0u; x < MAZE_W; x++) {
            uint8_t w = 0u;
            if (y == 0u)                            w |= WALL_N;
            if (y == (uint8_t)(MAZE_H_CELLS - 1u))  w |= WALL_S;
            if (x == 0u)                            w |= WALL_W;
            if (x == (uint8_t)(MAZE_W - 1u))        w |= WALL_E;
            m->wall[maze_idx(x, y)] = w;
        }
    maze_divide(m, 0u, 0u, MAZE_W, MAZE_H_CELLS);
}

// ---------------------------------------------------------------------------------------------
// SOLVE — A* with an indexed binary min-heap (decrease-key) + Manhattan heuristic.
//
// start = cell (0,0); goal = cell (MAZE_W-1, MAZE_H_CELLS-1).

#define MAZE_GX ((uint8_t)(MAZE_W - 1u))
#define MAZE_GY ((uint8_t)(MAZE_H_CELLS - 1u))

static inline uint16_t maze_h(uint16_t cell) {
    uint8_t x = (uint8_t)(cell & MAZE_WMASK), y = (uint8_t)(cell >> MAZE_WSH);
    uint8_t dx = (uint8_t)(x > MAZE_GX ? x - MAZE_GX : MAZE_GX - x);
    uint8_t dy = (uint8_t)(y > MAZE_GY ? y - MAZE_GY : MAZE_GY - y);
    return (uint16_t)((uint16_t)dx + dy);
}

// f-key of a cell currently in the heap (g + h). Tie ordering: lower f, then lower cell id.
static inline uint16_t maze_key(maze_t *m, uint16_t cell) {
    return (uint16_t)(m->g[cell] + maze_h(cell));
}

// "a before b" total order: smaller key first, ties broken by smaller cell id.
static inline uint8_t maze_before(maze_t *m, uint16_t a, uint16_t b) {
    uint16_t ka = maze_key(m, a), kb = maze_key(m, b);
    if (ka != kb) return (uint8_t)(ka < kb);
    return (uint8_t)(a < b);
}

static inline void maze_hswap(maze_t *m, uint16_t i, uint16_t j) {
    uint16_t ci = m->heap[i], cj = m->heap[j];
    m->heap[i] = cj; m->heap[j] = ci;
    m->hpos[cj] = i; m->hpos[ci] = j;
}

static void maze_sift_up(maze_t *m, uint16_t i) {
    while (i > 0u) {
        uint16_t parent = (uint16_t)((i - 1u) >> 1);
        if (maze_before(m, m->heap[i], m->heap[parent])) { maze_hswap(m, i, parent); i = parent; }
        else break;
    }
}

static void maze_sift_down(maze_t *m, uint16_t i) {
    for (;;) {
        uint16_t l = (uint16_t)(2u * i + 1u), r = (uint16_t)(2u * i + 2u), best = i;
        if (l < m->hn && maze_before(m, m->heap[l], m->heap[best])) best = l;
        if (r < m->hn && maze_before(m, m->heap[r], m->heap[best])) best = r;
        if (best == i) break;
        maze_hswap(m, i, best); i = best;
    }
}

static void maze_heap_push(maze_t *m, uint16_t cell) {
    uint16_t i = m->hn++;
    m->heap[i] = cell; m->hpos[cell] = i;
    m->pushes++;
    maze_sift_up(m, i);
}

static uint16_t maze_heap_pop(maze_t *m) {
    uint16_t top = m->heap[0];
    m->hpos[top] = 0xFFFFu;
    m->hn--;
    if (m->hn > 0u) {
        m->heap[0] = m->heap[m->hn];
        m->hpos[m->heap[0]] = 0u;
        maze_sift_down(m, 0u);
    }
    return top;
}

// A* in two parts (init + step) so the on-console demo can animate one expansion per frame while
// the gate runs them back-to-back. maze_solve() drives them; the differential CRC is unchanged.

static void maze_solve_init(maze_t *m) {
    for (uint16_t i = 0; i < MAZE_N; i++) {
        m->g[i] = 0xFFFFu; m->came[i] = 0xFFu; m->vis[i] = ST_UNSEEN; m->hpos[i] = 0xFFFFu;
    }
    m->hn = 0u; m->expanded = 0u; m->pushes = 0u; m->path_len = 0xFFFFu;
    uint16_t start = maze_idx(0u, 0u);
    m->g[start] = 0u; m->vis[start] = ST_OPEN;
    maze_heap_push(m, start);
}

// Pop the best open node and relax its neighbours. Returns the popped cell, or 0xFFFF if the heap
// was empty. The caller stops when the returned cell is the goal. noinline: this is the A* live
// set — keeping it out of the driver/animation frame (a16/xy16-regalloc family mitigation).
__attribute__((noinline))
static uint16_t maze_solve_step(maze_t *m) {
    if (m->hn == 0u) return 0xFFFFu;
    uint16_t cur = maze_heap_pop(m);
    m->vis[cur] = ST_CLOSED;
    m->expanded++;
    if (cur == maze_idx(MAZE_GX, MAZE_GY)) { m->path_len = m->g[cur]; return cur; }

    uint8_t cx = (uint8_t)(cur & MAZE_WMASK), cy = (uint8_t)(cur >> MAZE_WSH);
    for (uint8_t d = 0u; d < 4u; d++) {
        if (m->wall[cur] & MAZE_WBIT[d]) continue;              // wall blocks this side
        int16_t nx = (int16_t)((int16_t)cx + MAZE_DX[d]);
        int16_t ny = (int16_t)((int16_t)cy + MAZE_DY[d]);
        if (nx < 0 || nx >= (int16_t)MAZE_W || ny < 0 || ny >= (int16_t)MAZE_H_CELLS)
            continue;
        uint16_t nb = maze_idx((uint8_t)nx, (uint8_t)ny);
        if (m->vis[nb] == ST_CLOSED) continue;
        uint16_t ng = (uint16_t)(m->g[cur] + 1u);
        if (ng < m->g[nb]) {
            m->g[nb]   = ng;
            m->came[nb] = (uint8_t)((d + 2u) & 3u);             // came FROM the opposite side
            if (m->vis[nb] == ST_OPEN) maze_sift_up(m, m->hpos[nb]);   // decrease-key
            else { m->vis[nb] = ST_OPEN; maze_heap_push(m, nb); }
        }
    }
    return cur;
}

// Run A* to completion. Returns path length in edges (0xFFFF if unreachable).
__attribute__((noinline))
static uint16_t maze_solve(maze_t *m) {
    maze_solve_init(m);
    uint16_t goal = maze_idx(MAZE_GX, MAZE_GY);
    for (;;) {
        uint16_t cur = maze_solve_step(m);
        if (cur == 0xFFFFu) { m->path_len = 0xFFFFu; break; }   // heap drained, goal unreachable
        if (cur == goal) break;
    }
    return m->path_len;
}

// ---------------------------------------------------------------------------------------------
// CRC utilities + the differential gate.

static inline uint16_t maze_fold(uint16_t h, uint16_t v) {
    uint16_t hi = (uint16_t)((h >> 15) & 1u);
    return (uint16_t)((((uint16_t)(h << 1)) | hi) ^ v);
}

// Fold the carved wall pattern. noinline: the gate's fold loops are split into their own
// callees so no single +mos-a16 function carries the whole carve+solve+fold live set — the
// documented mitigation for the a16-regalloc/verifier family (the mandel demo's noinline
// mandel_cell; see docs/agent-handoff.md). Each piece -verify-machineinstrs clean.
__attribute__((noinline))
static uint16_t maze_fold_walls(maze_t *m, uint16_t h) {
    for (uint16_t i = 0; i < MAZE_N; i++) h = maze_fold(h, (uint16_t)m->wall[i]);
    return h;
}

// Reconstruct the shortest path goal→start into heap[] (free after solve, so no extra bss) by
// walking came[]; returns the cell count. Bounded by MAZE_N so a broken/looping chain can't hang.
// noinline: its own small frame keeps register pressure down (the xy16-regalloc family runs out
// of registers if this folds into its caller). Reused by the on-console demo to light the path.
__attribute__((noinline))
static uint16_t maze_path_build(maze_t *m) {
    uint16_t cell = maze_idx(MAZE_GX, MAZE_GY);
    uint16_t start = maze_idx(0u, 0u);
    uint16_t n = 0u;
    for (uint16_t step = 0; step <= MAZE_N; step++) {
        m->heap[n++] = cell;
        if (cell == start) break;
        uint8_t d = m->came[cell];                                // direction we came FROM
        uint8_t nx = (uint8_t)((cell & MAZE_WMASK) + MAZE_DX[d]);
        uint8_t ny = (uint8_t)((cell >> MAZE_WSH) + MAZE_DY[d]);
        cell = maze_idx(nx, ny);
    }
    return n;
}

// Fold the shortest path (sensitive to any A* or heap-ordering miscompile). Reconstruct, then
// fold the flat array — two simple passes, never fold-while-walking (the combined load-at-top /
// step-at-bottom loop makes GISel hoist a merge past its use, "defs don't dominate all uses").
__attribute__((noinline))
static uint16_t maze_fold_path(maze_t *m, uint16_t h) {
    if (m->path_len == 0xFFFFu) return h;
    uint16_t n = maze_path_build(m);
    for (uint16_t i = 0; i < n; i++) {
        uint16_t c = m->heap[i];
        h = maze_fold(h, (uint16_t)((c << 2) | m->came[c]));
    }
    return h;
}

// Differential gate CRC: generate (recursive carve) + solve (A* heap) on a fixed-seed maze and
// fold the carved wall pattern, the A* path, and the heap op counters into a uint16. SAME
// computation on host and 65816 — both must agree.
//
// Takes pre-allocated state (the on-console App already owns a maze_t — avoids a second large
// static allocation), like pi_gate_crc / spiro corpus.
__attribute__((noinline))
static uint16_t maze_gate_crc(maze_t *m) {
    maze_generate(m, 0xC0DEu);
    uint16_t pl = maze_solve(m);
    uint16_t h = maze_fold_walls(m, 0u);
    h = maze_fold(h, pl);
    h = maze_fold(h, m->expanded);
    h = maze_fold(h, m->pushes);
    h = maze_fold_path(m, h);
    return h;
}

#endif /* MAZE_H */
