// Shared, PURE 3-D cellular-automaton on a true multi-dimensional array — host-linkable.  Demo #72.
//
// The codegen corner: **multi-dimensional array indexing** — a genuine `uint8_t grid[D][D][D]` accessed
// as `grid[z][y][x]`, so the COMPILER generates the row/plane stride arithmetic `z*(D*D) + y*D + x`
// (D = 6, non-power-of-2 → strides 36 and 6).  Every prior grid demo was 1-D or hand-indexed `y*W+x`;
// this is the first that leans on the compiler's N-dimensional GEP lowering — and it does so 26 times
// per cell (the Moore neighbourhood) plus once per fold, across two double-buffered 3-D arrays.
//
// Everything is `uint8_t`/`int` cells — bit-exact host vs target by construction (the indexing must
// compute the same linear offset both ways).  The automaton is a 3-D life-like rule (survive 4..7, born
// 5..6, Moore-26, toroidal wrap) that stays active.  See docs/plans/2026-06-30-72-snes-grid3d.md.
#ifndef GRID3D_H
#define GRID3D_H

#include <stdint.h>

#define G3D 6                        // cube side (non-power-of-2 -> real stride arithmetic)
#define G3_S0 4                      // survive if 4..7 live neighbours
#define G3_S1 7
#define G3_B0 5                      // born if 5..6 live neighbours
#define G3_B1 6

static uint8_t g3_a[G3D][G3D][G3D];  // double-buffered cell grids (true 3-D arrays)
static uint8_t g3_b[G3D][G3D][G3D];

static inline uint8_t g3_wrap(int8_t v) {
    return (uint8_t)(v < 0 ? v + G3D : (v >= G3D ? v - G3D : v));
}

// Count the 26 Moore neighbours of (x,y,z) with toroidal wrap — the multi-dimensional-indexing hot spot
// (each read is a compiler-generated grid[z][y][x] = z*36 + y*6 + x offset).
static uint8_t g3_neighbours(uint8_t g[G3D][G3D][G3D], uint8_t x, uint8_t y, uint8_t z) {
    uint8_t c = 0;
    for (int8_t dz = -1; dz <= 1; dz++)
        for (int8_t dy = -1; dy <= 1; dy++)
            for (int8_t dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0 && dz == 0) continue;
                uint8_t zz = g3_wrap((int8_t)(z + dz));
                uint8_t yy = g3_wrap((int8_t)(y + dy));
                uint8_t xx = g3_wrap((int8_t)(x + dx));
                c = (uint8_t)(c + g[zz][yy][xx]);        // <-- multi-dim read
            }
    return c;
}

// One automaton step: dst[z][y][x] = rule(src neighbours).  Reads/writes both 3-D arrays.
static void g3_step(uint8_t src[G3D][G3D][G3D], uint8_t dst[G3D][G3D][G3D]) {
    for (uint8_t z = 0u; z < G3D; z++)
        for (uint8_t y = 0u; y < G3D; y++)
            for (uint8_t x = 0u; x < G3D; x++) {
                uint8_t c = g3_neighbours(src, x, y, z);
                uint8_t alive = src[z][y][x];
                uint8_t next = (uint8_t)((alive ? (c >= G3_S0 && c <= G3_S1)
                                                : (c >= G3_B0 && c <= G3_B1)) ? 1u : 0u);
                dst[z][y][x] = next;                     // <-- multi-dim write
            }
}

// Seed a deterministic small cluster (identical host/target) into g3_a.
static void g3_seed(void) {
    for (uint8_t z = 0u; z < G3D; z++)
        for (uint8_t y = 0u; y < G3D; y++)
            for (uint8_t x = 0u; x < G3D; x++) g3_a[z][y][x] = 0u;
    uint16_t s = 0x1234u;
    for (uint8_t i = 0u; i < 60u; i++) {
        s ^= (uint16_t)(s << 7); s ^= (uint16_t)(s >> 9); s ^= (uint16_t)(s << 8);
        uint8_t x = (uint8_t)(1u + (s % 4u));
        uint8_t y = (uint8_t)(1u + ((s >> 3) % 4u));
        uint8_t z = (uint8_t)(1u + ((s >> 6) % 4u));
        g3_a[z][y][x] = 1u;
    }
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t g3_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 3u                    // automaton steps folded into the gate (Moore-26 is heavy; keep small
#endif                               // so the synchronous startup gate settles before the title fades)

// Seed, then step the automaton GATE_N times, folding every cell (mixed with its 3-D coordinate) and the
// population after each step.  A miscompile in the grid[z][y][x] stride arithmetic, the neighbour walk,
// or the rule diverges the hash.
static uint16_t grid3d_gate_crc(void) {
    g3_seed();
    uint16_t h = 0u;
    for (uint16_t f = 0u; f < (uint16_t)GATE_N; f++) {
        g3_step(g3_a, g3_b);
        uint16_t pop = 0u;
        for (uint8_t z = 0u; z < G3D; z++)
            for (uint8_t y = 0u; y < G3D; y++)
                for (uint8_t x = 0u; x < G3D; x++) {
                    uint8_t v = g3_b[z][y][x];
                    pop = (uint16_t)(pop + v);
                    h = g3_fold(h, (uint16_t)(v ^ (uint16_t)((x << 8) ^ (y << 4) ^ z)));
                    g3_a[z][y][x] = v;                   // copy back for the next step
                }
        h = g3_fold(h, pop);
    }
    return h;
}

#endif /* GRID3D_H */
