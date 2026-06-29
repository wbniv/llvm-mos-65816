/* life.h — Conway's Game of Life (B3/S23), bit-packed grid, SWAR neighbour sums.
 *
 * Packed rows: 1 bit/cell, MSB-first within a byte — bit 7 of byte b of row y is cell (8*b, y),
 * bit 0 is cell (8*b+7, y). This bit order makes a packed byte IDENTICAL to a 2bpp bitplane byte,
 * so the SNES renderer (examples/snes/life.c) copies grid bytes straight into tile chr.
 *
 * life_step() computes one generation by adding the eight neighbour bit-vectors of each grid byte
 * into a 4-bit-per-cell count with a ripple of half-adders (carry = a & b; sum = a ^ b) — pure
 * and/eor/ora boolean codegen on 8-bit values, no per-cell branch, no arithmetic libcalls. Borders
 * are dead (cells outside the grid count as 0).
 *
 * life_gate_crc() — pure function, GATE_N generations of a Gosper glider gun on a small grid, folds
 * every output row into a CRC-16 and returns the uint16_t result (the differential anchor). Portable
 * C99, <stdint.h> only — no bare int (16-bit on target, 32-bit on host): every value here fits in
 * a uint8_t/uint16_t so host and target agree exactly. */
#ifndef LIFE_LOGIC_H
#define LIFE_LOGIC_H

#include <stdint.h>

/* --- gate grid geometry (small, for a fast deterministic CRC) ------------------------------- */
#define LIFE_GATE_WBYTES  8u    /* 64 cells wide  */
#define LIFE_GATE_H      48u    /* 48 cells tall  */
#define LIFE_GATE_GENS   32u    /* generations folded into the CRC */

/* life_step — one generation. src/dst each h*wbytes bytes (src != dst). Dead borders.
 * The eight neighbour bit-vectors per byte are summed bit-parallel into a 4-bit count across the
 * bitplanes c0..c3; the rule selects count==2 (survive) / count==3 (born or survive). noinline:
 * bounds +mos-a16/+mos-xy16 register pressure (handoff §4), like ca_step.
 *
 * Dead borders are handled by gating the off-grid reads with has_p/has_n (top/bottom) and lok/rok
 * (left/right byte) — every pointer stays inside src (bank-0 WRAM near pointer), so no const
 * "zero row" in a different bank is ever dereferenced (which would read the wrong data bank). */
__attribute__((noinline))
static void life_step(const uint8_t *src, uint8_t *dst, uint8_t wbytes, uint8_t h) {
    uint8_t y, b;
    for (y = 0; y < h; y++) {
        uint8_t has_p = (uint8_t)(y > 0u);
        uint8_t has_n = (uint8_t)(y < (uint8_t)(h - 1u));
        const uint8_t *prow = has_p ? (src + (uint16_t)(y - 1u) * wbytes) : (src + (uint16_t)y * wbytes);
        const uint8_t *crow =          src + (uint16_t)y * wbytes;
        const uint8_t *nrow = has_n ? (src + (uint16_t)(y + 1u) * wbytes) : (src + (uint16_t)y * wbytes);
        uint8_t *drow = dst + (uint16_t)y * wbytes;
        for (b = 0; b < wbytes; b++) {
            uint8_t lok = (uint8_t)(b > 0u);
            uint8_t rok = (uint8_t)(b < (uint8_t)(wbytes - 1u));
            uint8_t pc = has_p ? prow[b] : 0u;
            uint8_t cc = crow[b];
            uint8_t nc = has_n ? nrow[b] : 0u;
            /* boundary bits from the adjacent bytes; 0 at the row ends → dead L/R border.
             * left-neighbour byte feeds bit 0 into our bit 7; right-neighbour byte feeds bit 7
             * into our bit 0. */
            uint8_t pl = (has_p && lok) ? (uint8_t)(prow[b - 1u] & 1u) : 0u;
            uint8_t cl = (lok)          ? (uint8_t)(crow[b - 1u] & 1u) : 0u;
            uint8_t nl = (has_n && lok) ? (uint8_t)(nrow[b - 1u] & 1u) : 0u;
            uint8_t pr = (has_p && rok) ? (uint8_t)(prow[b + 1u] >> 7u) : 0u;
            uint8_t cr = (rok)          ? (uint8_t)(crow[b + 1u] >> 7u) : 0u;
            uint8_t nr = (has_n && rok) ? (uint8_t)(nrow[b + 1u] >> 7u) : 0u;

            uint8_t Lp = (uint8_t)((pc >> 1u) | (uint8_t)(pl << 7u));   /* prev row, left  neighbours */
            uint8_t Rp = (uint8_t)((pc << 1u) | pr);                    /* prev row, right neighbours */
            uint8_t Lc = (uint8_t)((cc >> 1u) | (uint8_t)(cl << 7u));   /* cur  row, left  neighbours */
            uint8_t Rc = (uint8_t)((cc << 1u) | cr);                    /* cur  row, right neighbours */
            uint8_t Ln = (uint8_t)((nc >> 1u) | (uint8_t)(nl << 7u));   /* next row, left  neighbours */
            uint8_t Rn = (uint8_t)((nc << 1u) | nr);                    /* next row, right neighbours */

            /* SWAR ripple-add the 8 neighbour bytes into a 4-bit-per-cell count (c0=1s..c3=8s). */
            uint8_t c0 = 0u, c1 = 0u, c2 = 0u, c3 = 0u, cy, t;
#define LIFE_ADD(x)  cy = (uint8_t)(c0 & (x)); c0 = (uint8_t)(c0 ^ (x)); \
                     t  = (uint8_t)(c1 & cy);  c1 = (uint8_t)(c1 ^ cy);  cy = t; \
                     t  = (uint8_t)(c2 & cy);  c2 = (uint8_t)(c2 ^ cy);  cy = t; \
                     c3 = (uint8_t)(c3 ^ cy)
            LIFE_ADD(Lp); LIFE_ADD(pc); LIFE_ADD(Rp);
            LIFE_ADD(Lc);               LIFE_ADD(Rc);
            LIFE_ADD(Ln); LIFE_ADD(nc); LIFE_ADD(Rn);
#undef LIFE_ADD
            /* count==2 → ~c3 & ~c2 & c1 & ~c0 ; count==3 → ~c3 & ~c2 & c1 & c0 */
            uint8_t two   = (uint8_t)((uint8_t)~c3 & (uint8_t)~c2 & c1 & (uint8_t)~c0);
            uint8_t three = (uint8_t)((uint8_t)~c3 & (uint8_t)~c2 & c1 & c0);
            drow[b] = (uint8_t)(three | (uint8_t)(cc & two));   /* B3/S23 */
        }
    }
}

/* Set the cell at (x,y) live in a packed grid (MSB-first bit order). */
static inline void life_set(uint8_t *grid, uint8_t wbytes, uint8_t x, uint8_t y) {
    grid[(uint16_t)y * wbytes + (uint16_t)(x >> 3u)] |= (uint8_t)(0x80u >> (uint8_t)(x & 7u));
}

/* Gosper glider gun (36×9 bounding box), placed with top-left at (ox,oy). The canonical
 * period-30 oscillator that emits a glider every 30 generations toward the bottom-right. */
static void life_seed_gun(uint8_t *grid, uint8_t wbytes, uint8_t ox, uint8_t oy) {
    /* {dx,dy} of every live cell, relative to the gun's top-left. */
    static const uint8_t gun[36][2] = {
        {0,4},{0,5},{1,4},{1,5},                                  /* left block */
        {10,4},{10,5},{10,6},{11,3},{11,7},{12,2},{12,8},{13,2},  /* left ship  */
        {13,8},{14,5},{15,3},{15,7},{16,4},{16,5},{16,6},{17,5},
        {20,2},{20,3},{20,4},{21,2},{21,3},{21,4},{22,1},{22,5},  /* right ship */
        {24,0},{24,1},{24,5},{24,6},
        {34,2},{34,3},{35,2},{35,3},                              /* right block */
    };
    uint8_t i;
    for (i = 0; i < 36u; i++)
        life_set(grid, wbytes, (uint8_t)(ox + gun[i][0]), (uint8_t)(oy + gun[i][1]));
}

/* CRC-16 (ARC polynomial 0xA001) fold of one row of `wbytes` packed bytes into the accumulator. */
static uint16_t life_crc16_row(uint16_t crc, const uint8_t *row, uint8_t wbytes) {
    uint8_t b, i;
    for (b = 0; b < wbytes; b++) {
        crc ^= (uint16_t)row[b];
        for (i = 0; i < 8u; i++)
            crc = (crc & 1u) ? (uint16_t)((crc >> 1u) ^ 0xA001u) : (uint16_t)(crc >> 1u);
    }
    return crc;
}

/* life_gate_crc — differential anchor: a Gosper gun on a 64×48 packed grid, LIFE_GATE_GENS
 * generations, CRC-16 of every output row each generation. Static scratch avoids a large
 * soft-stack frame in the corpus environment. */
static uint16_t life_gate_crc(void) {
    static uint8_t ga[LIFE_GATE_WBYTES * LIFE_GATE_H];
    static uint8_t gb[LIFE_GATE_WBYTES * LIFE_GATE_H];
    uint16_t i, gen;
    uint16_t crc = 0u;
    uint8_t  use_a, y;

    for (i = 0; i < (uint16_t)(LIFE_GATE_WBYTES * LIFE_GATE_H); i++) ga[i] = gb[i] = 0u;
    life_seed_gun(ga, LIFE_GATE_WBYTES, 2u, 2u);   /* fits the 64×48 grid with margin */
    use_a = 1u;

    for (gen = 0; gen < (uint16_t)LIFE_GATE_GENS; gen++) {
        const uint8_t *s = use_a ? ga : gb;
        uint8_t       *d = use_a ? gb : ga;
        life_step(s, d, LIFE_GATE_WBYTES, LIFE_GATE_H);
        for (y = 0; y < (uint8_t)LIFE_GATE_H; y++)
            crc = life_crc16_row(crc, d + (uint16_t)y * LIFE_GATE_WBYTES, LIFE_GATE_WBYTES);
        use_a ^= 1u;
    }
    return crc;
}

/* xorshift16 — deterministic PRNG for the renderer's display-only random soup (not used by the
 * gate). Same 3-tap as invaders_logic.h. */
static inline uint16_t life_rng16(uint16_t *s) {
    uint16_t x = *s;
    x ^= (uint16_t)(x << 7u);
    x ^= (uint16_t)(x >> 9u);
    x ^= (uint16_t)(x << 8u);
    *s = x;
    return x;
}

#endif /* LIFE_LOGIC_H */
