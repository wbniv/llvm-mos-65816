// Gather-Scatter Permutation (#95) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster A. Re-stresses patch 0002
// (`MOSInsertREPSEP::placeIntraBlock`, the #23 lsystem / +mos-xy16 index-width fix) at its HARDEST:
// a scatter `dst[perm[i]] = src[i]` over a 576-entry (> 512) grid, where the inner loop holds TWO
// 16-bit index values live SIMULTANEOUSLY — the loop counter `i` (indexing perm[] and src[]) and
// the DATA-DEPENDENT scatter index `pi = perm[i]` (indexing dst[]). This is the exact shape the
// #23 bug corrupted: a stray `sep #$10` between writing a 16-bit index and reading it would zero
// ONE of the two indices' high byte. Distinct from #93 ovmove (memmove libcall) and #94 rotslab
// (two ARITHMETIC indices lo/hi): here one index is a genuine table-loaded value used as a
// subscript, which cannot be strength-reduced to a stride.
//
// perm is a bijection (pi = (i*PS_MULT) % PS_N, PS_MULT coprime to PS_N), so the scatter is a pure
// permutation — every element lands exactly once. A dropped index high byte would drop/duplicate a
// cell AND diverge the position-sensitive CRC. Applied repeatedly (ping-pong a<->b), it shuffles
// kaleidoscopically. WIDTH DISCIPLINE: indices uint16_t; data uint8_t; no float; no runtime divide
// in the hot loop (the setup modulo builds perm once). Integer-exact differential.
// See docs/plans/2026-07-02-95-snes-permscat.md.

#ifndef PERMSCAT_H
#define PERMSCAT_H

#include <stdint.h>

#define PS_W    24u                                          // grid columns
#define PS_H    24u                                          // grid rows
#define PS_N    ((uint16_t)((uint16_t)PS_W * (uint16_t)PS_H))  // 576 entries > 512 -> 16-bit index
#define PS_MULT 5u                                           // coprime to 576 = 2^6*3^2 -> bijection

static uint16_t ps_perm[PS_N];   // BSS: the permutation table (16-bit scatter indices)
static uint8_t  ps_a[PS_N];      // BSS: ping buffer
static uint8_t  ps_b[PS_N];      // BSS: pong buffer

static void ps_init(void) {
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)PS_N; i++)
        ps_perm[i] = (uint16_t)((uint16_t)((uint16_t)i * (uint16_t)PS_MULT) % (uint16_t)PS_N);  // setup bijection
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)PS_N; i++)
        ps_a[i] = (uint8_t)((uint8_t)((uint8_t)(i % (uint16_t)PS_W) ^ (uint8_t)(i / (uint16_t)PS_W)) & (uint8_t)3u);
}

// One scatter step. Even phase: ps_b[perm[i]] = ps_a[i]; odd phase: ps_a[perm[i]] = ps_b[i].
// Global array bases + a data-dependent 16-bit subscript pi=perm[i], live alongside the counter i.
// noinline to hold a realistic call boundary + register pressure across the width transitions.
__attribute__((noinline))
static void ps_step(uint16_t phase) {
    if (phase & (uint16_t)1u) {
        for (uint16_t i = (uint16_t)0u; i < (uint16_t)PS_N; i++)
            ps_a[ps_perm[i]] = ps_b[i];        // store at 16-bit index pi, load at 16-bit index i
    } else {
        for (uint16_t i = (uint16_t)0u; i < (uint16_t)PS_N; i++)
            ps_b[ps_perm[i]] = ps_a[i];
    }
}

// The buffer just written by ps_step(phase): even phase -> ps_b, odd phase -> ps_a.
static inline uint8_t *ps_dest(uint16_t phase) { return (phase & (uint16_t)1u) ? ps_a : ps_b; }

// Position-sensitive rotate-ADD fold (a permutation preserves the value multiset, so a plain XOR
// would be permutation-invariant; the running-hash position weight breaks that).
static inline uint16_t ps_fold(uint16_t h, uint16_t v, uint16_t step) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u))
                    + v
                    + (uint16_t)((uint16_t)step * (uint16_t)53u));
}

// --------------------------------------------------------------------------
// Differential gate: GATE_N scatter steps (ping-pong), fold all 576 dest cells per step.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 12u
#endif

static uint16_t permscat_gate_crc(void) {
    ps_init();
    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        ps_step(step);
        uint8_t *cur = ps_dest(step);
        for (uint16_t i = (uint16_t)0u; i < (uint16_t)PS_N; i++)
            h = ps_fold(h, (uint16_t)cur[i], step);
    }
    return h;
}

#endif /* PERMSCAT_H */
