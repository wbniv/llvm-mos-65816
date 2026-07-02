// Ulam Prime Sieve (#85) — shared, portable logic header.
//
// Stresses: VARIABLE-COUNT bit shifts via a bit-array set — `arr[i>>3] |= (1u<<(i&7))`
// and membership `(arr[i>>3] >> (i&7)) & 1`. The shift amount `i&7` is a RUNTIME value,
// so the compiler emits variable-count G_SHL/G_LSHR (a shift loop / table), not a fixed
// shift. Distinct from #5 life (fixed 1<<k masks), #28 hilbert (fixed bit twiddles).
// Sieve of Eratosthenes builds the set; the Ulam spiral renders it.
//
// WIDTH DISCIPLINE: uint16_t indices, uint8_t bit-array bytes. No bare int.
// DIFFERENTIAL: pure integer set operations — bit-identical host vs 65816. Any wrong
// variable-shift (off-by-one in the shift count, or a fixed-shift miscompile) flips
// membership bits and diverges the fold immediately.
//
// See docs/plans/2026-07-01-85-snes-ulam.md.

#ifndef ULAM_H
#define ULAM_H

#include <stdint.h>

#define UL_N       1024u                 // sieve range (bits)
#define UL_BYTES   (UL_N / 8u)           // 128 bytes
#ifndef UL_GATE_N
#define UL_GATE_N  UL_N
#endif

// Composite bit-array: bit k set == k is composite. (0 and 1 marked composite.)
static uint8_t ul_comp[UL_BYTES];

// Variable-count set/test — the codegen corner (i&7 is a runtime shift amount).
static inline void ul_set(uint16_t i) {
    ul_comp[i >> 3] = (uint8_t)(ul_comp[i >> 3] | (uint8_t)(1u << (uint8_t)(i & 7u))); // G_SHL var
}
static inline uint8_t ul_is_prime(uint16_t i) {
    return (uint8_t)(((ul_comp[i >> 3] >> (uint8_t)(i & 7u)) & 1u) ? 0u : 1u);          // G_LSHR var
}

// Sieve of Eratosthenes over [0, UL_N).
static inline void ul_sieve(void) {
    uint16_t i, j;
    for (i = 0u; i < (uint16_t)UL_BYTES; i++) ul_comp[i] = 0u;
    ul_set(0u); ul_set(1u);                       // 0,1 not prime
    for (i = 2u; (uint32_t)i * i < (uint32_t)UL_N; i++) {
        if (ul_is_prime(i)) {
            for (j = (uint16_t)(i * i); j < (uint16_t)UL_N; j = (uint16_t)(j + i)) ul_set(j);
        }
    }
}

// ------------------------------------------------------------------
// Gate CRC: sieve, then fold membership of every k with prime multipliers.
// The fold reads each bit via the variable-count shift, exercising G_LSHR.
// ------------------------------------------------------------------
static uint16_t ulam_gate_crc(void) {
    ul_sieve();
    uint16_t h = 0u;
    uint16_t k;
    for (k = 0u; k < (uint16_t)UL_GATE_N; k++) {
        uint8_t p = ul_is_prime(k);
        h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
        if (p) h = (uint16_t)(h ^ (uint16_t)((uint16_t)k * 97u));
        else   h = (uint16_t)(h ^ (uint16_t)((uint16_t)k * 13u));
    }
    return h;
}

// Ulam spiral: map step k (0-based) to (x,y) on a spiral centred at origin.
// Standard square-spiral walk (right, up, left, down with growing arm lengths).
static inline void ul_spiral_xy(uint16_t k, int16_t *x, int16_t *y) {
    int16_t px = 0, py = 0;
    int16_t dx = 1, dy = 0;      // start moving right
    int16_t seg = 1, step = 0, turns = 0;
    uint16_t n;
    for (n = 0u; n < k; n++) {
        px = (int16_t)(px + dx); py = (int16_t)(py + dy);
        step++;
        if (step == seg) {
            step = 0;
            // rotate direction 90° CCW: (dx,dy) -> (-dy,dx)... use CW spiral: (dx,dy)->(dy,-dx)
            int16_t ndx = dy, ndy = (int16_t)(-dx);
            dx = ndx; dy = ndy;
            turns++;
            if ((turns & 1) == 0) seg++;   // grow arm every 2 turns
        }
    }
    *x = px; *y = py;
}

#endif /* ULAM_H */
