// In-Place Block Rotate (#94) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster A. Re-stresses patch 0002
// (`MOSInsertREPSEP::placeIntraBlock`, the #23 lsystem / +mos-xy16 in-place-memmove fix where a
// stray `sep #$10` between an `ldx` (16-bit X write) and `lda abs,X16` (read) zeroed X's high
// byte) — but from a DIFFERENT angle than #93 ovmove: instead of the SDK `memmove` libcall,
// this is a HAND-WRITTEN three-reversal rotate of a 384-entry uint16_t buffer. The reversal's
// tight `buf[lo] <-> buf[hi]` swap loop issues INDEXED 16-bit loads/stores whose index registers
// (0..383, all > 255) cross the M/X width-flag boundary continuously — the exact machinery
// placeIntraBlock schedules rep/sep around, with NO memmove in sight. If the 0002 fix only
// covered the memmove path (not general 16-bit-indexed access under width transitions), a dropped
// index high byte swaps the WRONG element and diverges the byte-exact CRC.
//
// WIDTH DISCIPLINE: all values/indices uint16_t; no float; the only libcall is __umodhi (k %= n).
// DIFFERENTIAL: integer-exact — a rotate is a pure permutation, bit-identical host vs target.
// Every buffer entry carries a distinct per-index tag (low 14 bits) so any index corruption
// changes the CRC immediately; the top 2 bits are the visible barber-pole stripe.
// See docs/plans/2026-07-02-94-snes-rotslab.md.

#ifndef ROTSLAB_H
#define ROTSLAB_H

#include <stdint.h>

#define ROT_W  16u                                          // mosaic columns
#define ROT_H  24u                                          // mosaic rows
#define ROT_N  ((uint16_t)((uint16_t)ROT_W * (uint16_t)ROT_H))  // 384 entries > 256 -> 16-bit index

typedef struct { uint16_t buf[ROT_N]; } ROTState;

// init: top 2 bits = diagonal barber-pole stripe (the visible colour); low 14 bits = a distinct
// per-index tag so index corruption is detectable in the CRC.
static void rot_init(ROTState *s) {
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)ROT_N; i++) {
        uint16_t stripe = (uint16_t)((uint16_t)((uint16_t)(i % (uint16_t)ROT_W) + (uint16_t)(i / (uint16_t)ROT_W)) & (uint16_t)3u);
        uint16_t tag    = (uint16_t)((uint16_t)((uint16_t)0x9E37u * i) & (uint16_t)0x3FFFu);
        s->buf[i] = (uint16_t)((uint16_t)(stripe << 14) | tag);
    }
}

// reverse buf[lo..hi) in place. lo, hi are 16-bit indices into a 384-entry uint16_t buffer, so
// every buf[lo]/buf[hi] is a 16-bit-INDEXED load/store crossing the M/X width-flag boundary.
static void rot_reverse(uint16_t *buf, uint16_t lo, uint16_t hi) {
    while ((uint16_t)(lo + (uint16_t)1u) < hi) {
        hi = (uint16_t)(hi - (uint16_t)1u);
        uint16_t tmp = buf[lo];
        buf[lo] = buf[hi];
        buf[hi] = tmp;
        lo = (uint16_t)(lo + (uint16_t)1u);
    }
}

// rotate buf left by k via the three-reversal identity rev[0,k) . rev[k,n) . rev[0,n). All in
// place. noinline for a realistic call boundary + register pressure across the width transitions.
__attribute__((noinline))
static void rot_rotate_left(uint16_t *buf, uint16_t n, uint16_t k) {
    k = (uint16_t)(k % n);                 // runtime %  -> __umodhi
    rot_reverse(buf, (uint16_t)0u, k);
    rot_reverse(buf, k, n);
    rot_reverse(buf, (uint16_t)0u, n);
}

// Position-sensitive rotate-ADD fold (a permutation preserves the value multiset, so a plain XOR
// of values would be rotation-invariant; the running-hash position weight breaks that).
static inline uint16_t rot_fold(uint16_t h, uint16_t v, uint16_t step) {
    return (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & (uint16_t)1u))
                    + v
                    + (uint16_t)((uint16_t)step * (uint16_t)53u));
}

// --------------------------------------------------------------------------
// Differential gate: GATE_N rotate steps, k = 1 + 3*step (runtime); fold all 384 entries/step.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 12u
#endif

static ROTState _rot_gate;   // BSS (not soft-stack)

static uint16_t rotslab_gate_crc(void) {
    rot_init(&_rot_gate);
    uint16_t h = (uint16_t)0u;
    for (uint16_t step = (uint16_t)0u; step < (uint16_t)GATE_N; step++) {
        uint16_t k = (uint16_t)((uint16_t)1u + (uint16_t)((uint16_t)step * (uint16_t)3u));
        rot_rotate_left(_rot_gate.buf, (uint16_t)ROT_N, k);
        for (uint16_t i = (uint16_t)0u; i < (uint16_t)ROT_N; i++)
            h = rot_fold(h, _rot_gate.buf[i], step);
    }
    return h;
}

#endif /* ROTSLAB_H */
