// Hilbert curve — the shared, portable math for SNES demo #28.
//
// Implements the canonical d2xy / xy2d bijection (Skilling's formulation) using VARIABLE-COUNT
// 32-bit shifts as the hot operation.  The loop iterates over bit-position k=0..ORDER-1; every
// iteration executes `rx << k` and `ry << k` (and `1u << k` in the reflect) where k is a
// RUNTIME variable — LLVM cannot constant-fold these, so it emits:
//
//   __ashlsi3(rx, k)  — 32-bit left shift with variable count  (the corner no other demo runs)
//   __ashlsi3(1, k)   — same, for the scale factor
//   __lshrsi3(x, k)   — 32-bit right shift with variable count (in xy2d)
//
// Compare: TEA (#30) uses CONSTANT shifts (<<4, >>5) → inlined ASL+ROL at -Os, no libcall.
// Hilbert (#28) uses RUNTIME shifts → forced libcall even at -Os, hitting the novel corner.
//
// HILBERT_ORDER = 4 → 16×16 grid, d ∈ [0, 255].  The gate folds all 256 d→(x,y) pairs.
//
// NO bare int — every width explicit (uint32_t).  See CLAUDE.md §width rules.
#ifndef HILBERT_H
#define HILBERT_H

#include <stdint.h>

#define HILBERT_ORDER   4u                             /* curve order — 16×16 = 256 cells  */
#define HILBERT_N       (1u << HILBERT_ORDER)          /* 16                               */
#define HILBERT_NPTS    (1u << (2u * HILBERT_ORDER))   /* 256                              */

/* d2xy: convert Hilbert distance d to (x,y) in the HILBERT_N × HILBERT_N grid.
   Inner loop variable k (bit position) is NOT a compile-time constant:
     rx << k   → __ashlsi3(rx, k)
     ry << k   → __ashlsi3(ry, k)
     1u << k   → __ashlsi3(1, k)  (scale for reflect)                                     */
static inline void hil_d2xy(uint32_t d, uint32_t *px, uint32_t *py) {
    uint32_t x = 0u, y = 0u;
    for (uint32_t k = 0u; k < (uint32_t)HILBERT_ORDER; k++) {
        uint32_t rx = (uint32_t)(1u & (d >> 1u));
        uint32_t ry = (uint32_t)(1u & (d ^ rx));
        if (ry == 0u) {
            if (rx == 1u) {
                uint32_t s = (uint32_t)(1u << k);  /* __ashlsi3(1, k) — variable! */
                x = s - 1u - x;
                y = s - 1u - y;
            }
            uint32_t t = x; x = y; y = t;
        }
        x += (uint32_t)(rx << k);  /* __ashlsi3(rx, k) — variable! */
        y += (uint32_t)(ry << k);  /* __ashlsi3(ry, k) — variable! */
        d >>= 2u;
    }
    *px = x; *py = y;
}

/* xy2d: convert (x,y) to Hilbert distance d.
   Loop variable k drives `x >> k` and `y >> k` (variable-count right shifts):
     (x >> k) & 1  →  __lshrsi3(x, k)                                                    */
static inline uint32_t hil_xy2d(uint32_t x, uint32_t y) {
    uint32_t d = 0u;
    for (uint32_t k = (uint32_t)(HILBERT_ORDER - 1u); k < (uint32_t)HILBERT_ORDER; k--) {
        uint32_t rx = (uint32_t)((x >> k) & 1u);  /* __lshrsi3(x, k) — variable! */
        uint32_t ry = (uint32_t)((y >> k) & 1u);  /* __lshrsi3(y, k) — variable! */
        /* d += s² × (3·rx ^ ry) = (3·rx ^ ry) << (2·k) */
        d += (uint32_t)((uint32_t)(3u * rx ^ ry) << (uint32_t)(2u * k));  /* __ashlsi3! */
        if (ry == 0u) {
            if (rx == 1u) {
                uint32_t s = (uint32_t)(1u << k);
                x = s - 1u - x;
                y = s - 1u - y;
            }
            uint32_t t = x; x = y; y = t;
        }
    }
    return d;
}

/* Gate CRC: fold d→(x,y) AND xy2d round-trip into a rotate-XOR hash.
   Including hil_xy2d(x,y) (== d when correct) breaks the symmetry that makes
   a pure x/y fold collapse to 0 (every (x,y) in [0,15]² appears exactly once,
   causing the simple XOR to cancel).  A miscompile in d2xy OR xy2d diverges it. */
static inline uint16_t hilbert_gate_crc(void) {
    uint16_t h = 0u;
    for (uint32_t d = 0u; d < (uint32_t)HILBERT_NPTS; d++) {
        uint32_t x, y;
        hil_d2xy(d, &x, &y);
        uint32_t rt = hil_xy2d(x, y);   /* round-trip: equals d when correct */
        uint16_t v = (uint16_t)(rt + (uint16_t)(rt << 2u) + (uint16_t)x + (uint16_t)(y << 8u));
        h = (uint16_t)((h << 1u) | (h >> 15u)) ^ v;
    }
    return h;
}

#endif /* HILBERT_H */
