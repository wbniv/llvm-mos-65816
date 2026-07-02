// Overlap-Move Mosaic (#93) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster A, first-pick intersection. Re-stresses TWO fixes at once:
//   (1) #23 lsystem / patch 0002 `MOSInsertREPSEP::placeIntraBlock` — the +mos-xy16 in-place
//       memmove miscompile where a `sep #$10` between an `ldx` (16-bit X write) and an
//       `lda abs,X16` (read) zeroed X's high byte. The fix reloads the X-writer after `rep #$10`.
//   (2) #79 mvscrl — G_MEMMOVE's Descending (dst>src) AND Ascending (dst<src) overlap sub-paths
//       (MOSLegalizerInfo.cpp:422 .custom(); direction at compareOperandLocations :3145-3152).
//
// ESCALATION vs the demos that found those bugs: the buffer is OV_N = 16×24 = 384 bytes (> 256),
// so every memmove count (368 / 383 / 382) forces a 16-bit index in the SDK memmove — the exact
// width-flag boundary the #23 bug lived at — and BOTH overlap directions fire, repeatedly, under
// +mos-xy16. #23 lsystem used one incidental non-overlapping grow; #79 mvscrl used <256-byte
// bands (8-bit index). A dropped index high-byte streaks the mosaic AND diverges the byte-CRC.
//
// WIDTH DISCIPLINE: all values uint8_t/uint16_t; no float; no division.
// DIFFERENTIAL: integer-exact — memmove of a byte array is a pure data shuffle, bit-identical
// host vs target. Any 16-bit-index corruption (the #23 signature) changes the CRC immediately.
// See docs/plans/2026-07-02-93-snes-ovmove.md.

#ifndef OVMOVE_H
#define OVMOVE_H

#include <stdint.h>
// __builtin_memmove → llvm.memmove intrinsic → G_MEMMOVE (clang) / same semantics (gcc host).
#define _OV_MEMMOVE(d, s, n) __builtin_memmove((d), (s), (n))

#define OV_W  16u                        // mosaic columns
#define OV_H  24u                        // mosaic rows
#define OV_N  ((uint16_t)((uint16_t)OV_W * (uint16_t)OV_H))   // 384 bytes > 256 → 16-bit index

typedef struct { uint8_t cell[OV_H][OV_W]; } OVState;   // 384-byte flat buffer

static void ov_init(OVState *s) {
    for (uint16_t r = (uint16_t)0u; r < (uint16_t)OV_H; r++)
        for (uint16_t c = (uint16_t)0u; c < (uint16_t)OV_W; c++)
            s->cell[r][c] = (uint8_t)((uint8_t)((uint8_t)(r * (uint8_t)3u) + (uint8_t)(c * (uint8_t)5u)) & (uint8_t)3u);
}

// One scroll step. dir even → ASCENDING pair (dst<src); dir odd → DESCENDING pair (dst>src).
// Every memmove count is > 256 → the SDK memmove indexes with a 16-bit X (the #23 boundary).
__attribute__((noinline))
static void ov_step(OVState *s, uint16_t seed, uint8_t dir) {
    uint8_t *flat = &s->cell[0][0];
    if (dir & (uint8_t)1u) {
        // DESCENDING pair (dst > src, overlapping → Descending=true)
        _OV_MEMMOVE(&s->cell[1][0], &s->cell[0][0], (uint16_t)((uint16_t)(OV_H - 1u) * (uint16_t)OV_W)); // down 368B
        for (uint16_t c = (uint16_t)0u; c < (uint16_t)OV_W; c++)
            s->cell[0][c] = (uint8_t)((uint16_t)((uint16_t)seed + (uint16_t)(c * (uint16_t)7u)) & (uint16_t)3u);
        _OV_MEMMOVE(flat + 1, flat, (uint16_t)(OV_N - 1u));                                              // right 383B
        flat[0] = (uint8_t)((uint16_t)(seed >> 2) & (uint16_t)3u);
    } else {
        // ASCENDING pair (dst < src, overlapping → Descending=false)
        _OV_MEMMOVE(&s->cell[0][0], &s->cell[1][0], (uint16_t)((uint16_t)(OV_H - 1u) * (uint16_t)OV_W)); // up 368B
        for (uint16_t c = (uint16_t)0u; c < (uint16_t)OV_W; c++)
            s->cell[OV_H - 1u][c] = (uint8_t)((uint16_t)((uint16_t)seed + (uint16_t)(c * (uint16_t)11u) + (uint16_t)1u) & (uint16_t)3u);
        _OV_MEMMOVE(flat, flat + 2, (uint16_t)(OV_N - 2u));                                              // left 382B
        flat[OV_N - 1u] = (uint8_t)((uint16_t)(seed >> 4) & (uint16_t)3u);
        flat[OV_N - 2u] = (uint8_t)((uint16_t)(seed >> 6) & (uint16_t)3u);
    }
}

// Rotate-ADD fold with step bias (period-4 byte data → a pure-XOR fold would cancel to 0).
static inline uint16_t ov_fold(uint16_t h, uint16_t v, uint16_t step) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u))
                    + v
                    + (uint16_t)((uint16_t)step * (uint16_t)53u));
}

// --------------------------------------------------------------------------
// Differential gate: GATE_N steps, alternating descending/ascending pairs;
// fold all 384 buffer bytes per step.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 16u
#endif

static OVState _ov_gate;   // BSS (not soft-stack)

static uint16_t ovmove_gate_crc(void) {
    ov_init(&_ov_gate);
    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        ov_step(&_ov_gate, (uint16_t)((uint16_t)step * (uint16_t)9u), (uint8_t)step);
        uint8_t *flat = &_ov_gate.cell[0][0];
        for (uint16_t i = (uint16_t)0u; i < (uint16_t)OV_N; i++)
            h = ov_fold(h, (uint16_t)flat[i], step);
    }
    return h;
}

#endif /* OVMOVE_H */
