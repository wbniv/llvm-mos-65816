// Signed-Bitfield Terrain Sculptor (#78) — shared, portable logic header.
//
// Stresses G_SEXT_INREG via signed bitfield read-back:
//   struct { int16_t height:5, slope:4, flow:4; uint16_t mat:3; }
// Reading a signed field fires G_SEXT_INREG → .lower() at MOSLegalizerInfo.cpp:130:
//   sext_inreg(x, N) → shl(x, 16-N) >> (16-N)  (arithmetic shift pair)
// Distinct from:
//   #29b truchet  (uint16_t bitfields → zero-extend, no sign-extend)
//   #52 disbits   (uint32_t opcode:8 → zero-extend constant shifts)
// Neither used int16_t: N signed-bitfield container types, confirmed by grep.
//
// Algorithm: 16×16 dome-shaped terrain of SBCell structs.
//   Init: height = 8 - (hx²+hy²)/4 (dome); slope = (hx+hy)&7 - 4 (wave).
//   Step: read signed fields (G_SEXT_INREG × 3 per cell),
//         erode ridges (slope>0 → height--) and fill valleys (slope<0 → height++),
//         update flow as running-average of slope.
//   Gate: GATE_N steps; fold (ht*7)^(sl<<2)^(fl*3)^mat per cell per step.
//
// WIDTH DISCIPLINE: all values int16_t/uint16_t; no bare int; no float; no division
// (except compile-time constant /4 folded as >>2 by the compiler).
// DIFFERENTIAL: integer-exact — signed bitfield values are sign-extension of the
// packed bits, bit-identical host vs target; any wrong sext (e.g. zero-extend)
// diverges the CRC on negative height/slope/flow.
//
// See docs/plans/2026-07-01-78-snes-sbitfld.md.

#ifndef SBITFLD_H
#define SBITFLD_H

#include <stdint.h>

// ------------------------------------------------------------------
// Cell struct: 5+4+4+3 = 16 bits exactly, one storage unit.
// The three signed int16_t fields trigger G_SEXT_INREG on read-back.
// ------------------------------------------------------------------
typedef struct {
    int16_t  height : 5;   // [-16..15] terrain height
    int16_t  slope  : 4;   // [-8..7]   erosion gradient
    int16_t  flow   : 4;   // [-8..7]   flow accumulator
    uint16_t mat    : 3;   // [0..7]    material (unsigned, no sext)
} SBCell;

#define SB_W 16u
#define SB_H 16u

// ------------------------------------------------------------------
// Init: dome shape centered at (8,8).
// ------------------------------------------------------------------
static void sb_init(SBCell grid[SB_H][SB_W]) {
    uint16_t y, x;
    for (y = (uint16_t)0u; y < (uint16_t)SB_H; y++) {
        for (x = (uint16_t)0u; x < (uint16_t)SB_W; x++) {
            int16_t hx = (int16_t)((int16_t)x - (int16_t)8);
            int16_t hy = (int16_t)((int16_t)y - (int16_t)8);
            // r2 = hx²+hy² ∈ [0,128]; /4 ∈ [0,32]; 8-r2/4 ∈ [-24,8] → clamp [-16,15].
            int16_t r2 = (int16_t)((int16_t)((int16_t)hx*(int16_t)hx) +
                                   (int16_t)((int16_t)hy*(int16_t)hy));
            int16_t h  = (int16_t)((int16_t)8 - (int16_t)(r2 >> (int16_t)2));
            if (h > (int16_t)15)  h = (int16_t)15;
            if (h < (int16_t)-16) h = (int16_t)-16;
            // slope: (hx+hy) mod 8, biased to [-4,3].
            int16_t s = (int16_t)((int16_t)((int16_t)((int16_t)hx + hy) & (int16_t)7) - (int16_t)4);
            grid[y][x].height = h;
            grid[y][x].slope  = s;
            grid[y][x].flow   = (int16_t)0;
            grid[y][x].mat    = (uint16_t)((uint16_t)(x ^ y) & (uint16_t)7u);
        }
    }
}

// ------------------------------------------------------------------
// One erosion step.  Signed field reads trigger G_SEXT_INREG × 3/cell.
// ------------------------------------------------------------------
__attribute__((noinline))
static void sb_step(SBCell grid[SB_H][SB_W]) {
    uint16_t y, x;
    for (y = (uint16_t)0u; y < (uint16_t)SB_H; y++) {
        for (x = (uint16_t)0u; x < (uint16_t)SB_W; x++) {
            int16_t h = grid[y][x].height;  // G_SEXT_INREG 5-bit signed
            int16_t s = grid[y][x].slope;   // G_SEXT_INREG 4-bit signed
            int16_t f = grid[y][x].flow;    // G_SEXT_INREG 4-bit signed
            // Ridges erode; valleys fill.
            if (s > (int16_t)0) {
                h = (int16_t)(h - (int16_t)1);
                if (h < (int16_t)-16) h = (int16_t)-16;
            } else if (s < (int16_t)0) {
                h = (int16_t)(h + (int16_t)1);
                if (h > (int16_t)15) h = (int16_t)15;
            }
            // Flow: running average of slope (arithmetic right-shift → signed).
            f = (int16_t)((int16_t)(f + s) >> (int16_t)1);
            if (f > (int16_t)7)  f = (int16_t)7;
            if (f < (int16_t)-8) f = (int16_t)-8;
            grid[y][x].height = h;
            grid[y][x].flow   = f;
        }
    }
}

// Colour [0..3] from signed height.
static inline uint8_t sb_color(int16_t h) {
    if (h < (int16_t)-4) return (uint8_t)0u;  // deep valley
    if (h < (int16_t) 0) return (uint8_t)1u;  // shallow valley
    if (h < (int16_t) 8) return (uint8_t)2u;  // low ridge
    return (uint8_t)3u;                         // high ridge
}

// CRC fold step.
static inline uint16_t sb_fold(uint16_t acc, uint16_t v) {
    return (uint16_t)((uint16_t)((uint16_t)(acc << 1) | (uint16_t)((acc >> 15) & (uint16_t)1u)) ^ v);
}

// ------------------------------------------------------------------
// Differential gate: GATE_N steps; fold all signed field reads.
// Static grid (BSS) avoids large soft-stack frame.
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 16u
#endif

static SBCell _sb_grid[SB_H][SB_W];  // BSS (not soft-stack)

static uint16_t sbitfld_gate_crc(void) {
    sb_init(_sb_grid);
    uint16_t h = (uint16_t)0u;
    uint16_t step;
    for (step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        sb_step(_sb_grid);
        uint16_t y, x;
        for (y = (uint16_t)0u; y < (uint16_t)SB_H; y++) {
            for (x = (uint16_t)0u; x < (uint16_t)SB_W; x++) {
                // Three G_SEXT_INREG reads per cell:
                int16_t  ht = _sb_grid[y][x].height;
                int16_t  sl = _sb_grid[y][x].slope;
                int16_t  fl = _sb_grid[y][x].flow;
                uint16_t mt = _sb_grid[y][x].mat;   // unsigned, no sext
                // Fold: mix signed values with multiplications and XOR.
                uint16_t fv = (uint16_t)((uint16_t)((uint16_t)ht * (uint16_t)7u)
                               ^ (uint16_t)((uint16_t)sl << (uint16_t)2u))
                             ^ (uint16_t)((uint16_t)((uint16_t)fl * (uint16_t)3u) ^ mt);
                h = sb_fold(h, fv);
            }
        }
    }
    return h;
}

#endif /* SBITFLD_H */
