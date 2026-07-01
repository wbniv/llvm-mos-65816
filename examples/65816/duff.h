// Shared, PURE Duff's-device unrolled copy — host-linkable, no hardware.  Demo #42.
//
// The codegen corner: **irreducible loop-switch control flow** — the classic Duff's device, a `switch`
// whose case labels land in the MIDDLE of a `do/while` loop body.  The interlacing of the switch's
// jump targets with the loop back-edge produces a CFG that cannot be reduced to structured
// if/while nesting; the backend must lower the tangle of branches directly and correctly.  A dissolve
// transition drives it: a source buffer is copied into a destination in unrolled 8-at-a-time bursts,
// the remainder handled by jumping into the unrolled body at the right offset.
//
// Width discipline (host int=32 / target int=16 must agree byte-for-byte):
//   - counts/indices are uint16_t; buffer bytes are uint8_t; the fold masks every step to uint16_t
// See docs/plans/2026-06-30-42-snes-duff.md.
#ifndef DUFF_H
#define DUFF_H

#include <stdint.h>

// Duff's device: copy `count` bytes from `from` to `to`, unrolled 8x with the switch entering the
// loop body at the residue offset.  The switch/loop interlace is the irreducible control flow.
static void duff_copy(uint8_t *to, const uint8_t *from, uint16_t count) {
    if (count == 0u) return;
    uint16_t n = (uint16_t)((count + 7u) / 8u);       // number of loop trips (rounded up)
    switch (count % 8u) {
        case 0: do { *to++ = *from++;   /* fall through */
        case 7:      *to++ = *from++;   /* fall through */
        case 6:      *to++ = *from++;   /* fall through */
        case 5:      *to++ = *from++;   /* fall through */
        case 4:      *to++ = *from++;   /* fall through */
        case 3:      *to++ = *from++;   /* fall through */
        case 2:      *to++ = *from++;   /* fall through */
        case 1:      *to++ = *from++;   /* fall through */
                   } while (--n > 0u);
    }
}

// ---------------------------------------------------------------------------------------------
// Differential gate: copy every residue length 1..40 through Duff's device, folding each result.

static inline uint16_t duff_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 40u        // max copy length exercised (hits every case entry point many times)
#endif

#define DUFF_BUF 48u

static uint16_t duff_gate_crc(void) {
    static uint8_t src[DUFF_BUF];
    static uint8_t dst[DUFF_BUF];
    for (uint16_t i = 0; i < DUFF_BUF; i++)
        src[i] = (uint8_t)(i * 7u + 3u);
    uint16_t h = 0;
    for (uint16_t count = 1; count <= (uint16_t)GATE_N; count++) {
        for (uint16_t i = 0; i < DUFF_BUF; i++) dst[i] = 0u;
        duff_copy(dst, src, count);                    // the irreducible copy
        uint16_t s = count;
        for (uint16_t i = 0; i < DUFF_BUF; i++)
            s = (uint16_t)((uint16_t)(s * 31u) + dst[i]);
        h = duff_fold(h, s);
    }
    return h;
}

#endif /* DUFF_H */
