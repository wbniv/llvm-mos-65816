// Descending memmove Scroll Slabs (#79) — shared, portable logic header.
//
// Stresses:
//   memmove(buf+1, buf, N-1) — dst > src, overlapping → Descending=true (high-to-low)
//   memmove(buf,   buf+1, N-1) — dst < src, overlapping → Descending=false (low-to-high)
// Both sub-paths of G_MEMMOVE at MOSLegalizerInfo.cpp:422 (.custom();
// descending detection at compareOperandLocations :3145-3152; offset adjust :3231/:3247).
// SDK memmove: llvm-mos-sdk mos-platform/common/c/mem.c:15 (weak impl).
// Distinct from:
//   #23 lsystem: memmove for string-rewriting (incidental, non-overlapping)
//   #49 lzdec:   overlapping back-ref copy byte-by-byte, never emits G_MEMMOVE
//
// Visual: 16×16 tile grid split in two 8-row bands.
//   Upper band scrolls DOWN via memmove(upper+row1, upper+row0, 7×16) — descending.
//   Lower band scrolls UP   via memmove(lower+row0, lower+row1, 7×16) — ascending.
//   New rows injected at the scroll boundary; bands meet in the middle.
//
// WIDTH DISCIPLINE: all values uint8_t/uint16_t; no float; no division.
// DIFFERENTIAL: integer-exact — memmove of a byte array is a pure data shuffle,
// bit-identical host vs target.  Wrong direction (ascending instead of descending)
// smears the upper band upward and changes the CRC immediately.
//
// See docs/plans/2026-07-01-79-snes-mvscrl.md.

#ifndef MVSCRL_H
#define MVSCRL_H

#include <stdint.h>
// memmove via builtin: avoids string.h include-path issues in the corpus
// cross-compile environment.  __builtin_memmove is recognized by both clang
// (→ llvm.memmove intrinsic → G_MEMMOVE) and gcc (same semantic as memmove).
#define _MV_MEMMOVE(d, s, n) __builtin_memmove((d), (s), (n))

#define MV_ROWS  8u    // rows per band (8 × 2 bands = 16 tile rows)
#define MV_COLS  16u   // columns (= NTILES_W)
#define MV_ROW_BYTES ((uint16_t)(MV_COLS))   // bytes per row

// Two scroll bands: upper scrolls down, lower scrolls up.
typedef struct {
    uint8_t upper[MV_ROWS][MV_COLS];   // tile colour bytes 0..3
    uint8_t lower[MV_ROWS][MV_COLS];
} MVState;

static void mv_init(MVState *s) {
    uint16_t r, c;
    for (r = (uint16_t)0u; r < (uint16_t)MV_ROWS; r++) {
        for (c = (uint16_t)0u; c < (uint16_t)MV_COLS; c++) {
            s->upper[r][c] = (uint8_t)((uint8_t)(r ^ c) & (uint8_t)3u);
            s->lower[r][c] = (uint8_t)((uint8_t)((uint8_t)(r + (uint8_t)4u) ^ (uint8_t)c) & (uint8_t)3u);
        }
    }
}

// One scroll step.  `seed` drives the new-row colour pattern.
// memmove with overlapping dst>src → Descending path.
// memmove with overlapping dst<src → Ascending path.
__attribute__((noinline))
static void mv_step(MVState *s, uint16_t seed) {
    // Upper band: scroll DOWN (shift rows 0..6 → rows 1..7; insert new row at top).
    // dst = &upper[1][0], src = &upper[0][0]; dst > src, they overlap → Descending.
    _MV_MEMMOVE(&s->upper[1][0], &s->upper[0][0], (MV_ROWS - 1u) * MV_ROW_BYTES);
    // Inject new top row from seed.
    uint16_t c;
    for (c = (uint16_t)0u; c < (uint16_t)MV_COLS; c++) {
        s->upper[0][c] = (uint8_t)((uint16_t)((uint16_t)(seed + (uint16_t)(c * (uint16_t)7u))) & (uint16_t)3u);
    }

    // Lower band: scroll UP (shift rows 1..7 → rows 0..6; insert new row at bottom).
    // dst = &lower[0][0], src = &lower[1][0]; dst < src, they overlap → Ascending.
    _MV_MEMMOVE(&s->lower[0][0], &s->lower[1][0], (MV_ROWS - 1u) * MV_ROW_BYTES);
    // Inject new bottom row from seed.
    for (c = (uint16_t)0u; c < (uint16_t)MV_COLS; c++) {
        s->lower[MV_ROWS - 1u][c] = (uint8_t)((uint16_t)((uint16_t)(seed + (uint16_t)(c * (uint16_t)13u) + (uint16_t)2u)) & (uint16_t)3u);
    }
}

// ------------------------------------------------------------------
// Rotate-add CRC fold with step bias.  Avoids pure XOR cancellation:
// the injected rows have period-4 byte patterns whose XOR is 0, so
// a plain rotating-XOR fold collapses to 0 at every step.  ADDITION
// is non-canceling: sum(v in {0,1,2,3}) = 6 ≠ 0 accumulates across
// all 256 folds per step.  step*53 is fast (strength-reduces to shifts).
// ------------------------------------------------------------------
static inline uint16_t mv_fold(uint16_t h, uint16_t v, uint16_t step) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u))
                    + v
                    + (uint16_t)((uint16_t)step * (uint16_t)53u));
}

// ------------------------------------------------------------------
// Differential gate: GATE_N steps; fold all tile bytes per step.
// Seed = step × 9.  GATE_N = 16 (fast: memmove + byte loops, no float,
// no large multiplications → completes well within 500-frame window).
// GATE_N=16 → CRC=0x72A7 (non-zero; verified host==default==a16==xy16).
// ------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 16u
#endif

static MVState _mv_gate_state;  // BSS (not soft-stack)

static uint16_t mvscrl_gate_crc(void) {
    mv_init(&_mv_gate_state);
    uint16_t h = (uint16_t)0u;
    uint16_t step;
    for (step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        mv_step(&_mv_gate_state, (uint16_t)(step * (uint16_t)9u));
        uint16_t r, c;
        for (r = (uint16_t)0u; r < (uint16_t)MV_ROWS; r++) {
            for (c = (uint16_t)0u; c < (uint16_t)MV_COLS; c++) {
                h = mv_fold(h, (uint16_t)_mv_gate_state.upper[r][c], step);
                h = mv_fold(h, (uint16_t)_mv_gate_state.lower[r][c], step);
            }
        }
    }
    return h;
}

#endif /* MVSCRL_H */
