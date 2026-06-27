/* ca1d.h — 1-D Elementary Cellular Automaton (256 cells, 1 bit/cell).
 *
 * Bitpacked rows: uint8_t cur[32], 1 bit per cell (bit k of byte b = cell b*8+k).
 * ca_step() computes one generation from 3-bit neighbourhood; wrap-around at both ends.
 * ca_gate_crc() — pure function, 32 gens Rule 90 + 32 gens Rule 110, folds all output
 * rows into a CRC-16 and returns the uint16_t result. Portable C99, <stdint.h> only. */
#ifndef CA1D_H
#define CA1D_H

#include <stdint.h>

#define CA_CELLS     256u
#define CA_BYTES      32u    /* CA_CELLS / 8 */
#define CA_RULE_90    90u
#define CA_RULE_110  110u
#define CA_GATE_GENS  64u    /* 32 Rule 90 + 32 Rule 110 */

/* ca_step — one CA generation. src/dst must each be CA_BYTES bytes; may alias only if src==dst.
 * Wrap-around: left of cell 0 = cell 255; right of cell 255 = cell 0.
 *
 * Optimised for the 65816: the rule is pre-expanded into an 8-byte lookup table (rl[]) once
 * per call, replacing variable-amount shifts (slow: loop per bit) in the inner loop with a
 * single WRAM byte load. The sliding window (win >>= 1, mask <<= 1) uses only constant-1
 * shifts throughout — the dominant codegen corner is the boolean sequence eor/and/ora/asl/lsr.
 * noinline: bounds +mos-a16/+mos-xy16 register pressure. */
__attribute__((noinline))
static void ca_step(const uint8_t *src, uint8_t *dst, uint8_t rule) {
    static uint8_t rl[8];   /* rule_bit[pat]: static = fixed WRAM addr, avoids soft-stack ptr */
    uint8_t b, k;
    for (k = 0; k < 8u; k++) rl[k] = (uint8_t)((rule >> k) & 1u);

    for (b = 0; b < (uint8_t)CA_BYTES; b++) {
        uint8_t prev = src[(uint8_t)(b - 1u) & (uint8_t)(CA_BYTES - 1u)];
        uint8_t curr = src[b];
        uint8_t next = src[(uint8_t)(b + 1u) & (uint8_t)(CA_BYTES - 1u)];
        uint8_t out  = 0;
        uint8_t mask = 1u;
        uint8_t lbit = (uint8_t)((prev >> 7u) & 1u);  /* left-neighbour of bit 0 */
        uint8_t win  = curr;                            /* bit 0 = current cell; slides right */
        for (k = 0; k < 8u; k++) {
            uint8_t cbit = (uint8_t)(win & 1u);
            uint8_t rbit = (k < 7u) ? (uint8_t)((win >> 1u) & 1u) : (uint8_t)(next & 1u);
            uint8_t pat  = (uint8_t)((lbit << 2u) | (cbit << 1u) | rbit);
            if (rl[pat]) out |= mask;
            lbit = cbit;
            mask = (uint8_t)(mask << 1u);  /* constant-1 shift */
            win  = (uint8_t)(win  >> 1u);  /* constant-1 shift */
        }
        dst[b] = out;
    }
}

/* CRC-16 (CRC-ARC polynomial 0xA001) fold of one CA row into accumulator. */
static uint16_t ca_crc16_row(uint16_t crc, const uint8_t *row) {
    uint8_t b;
    for (b = 0; b < (uint8_t)CA_BYTES; b++) {
        uint8_t i;
        crc ^= (uint16_t)row[b];
        for (i = 0; i < 8u; i++)
            crc = (crc & 1u) ? (uint16_t)((crc >> 1u) ^ 0xA001u)
                             : (uint16_t)(crc >> 1u);
    }
    return crc;
}

/* ca_gate_crc — differential anchor: 32 Rule-90 gens from a single-cell seed,
 * then 32 Rule-110 gens continuing from that state; CRC-16 of every output row.
 * Static scratch avoids a 64-byte stack frame in the corpus environment. */
static uint16_t ca_gate_crc(void) {
    static uint8_t ga[CA_BYTES], gb[CA_BYTES];
    uint8_t b, use_a;
    uint16_t gen;
    uint16_t crc = 0;

    for (b = 0; b < (uint8_t)CA_BYTES; b++) ga[b] = gb[b] = 0;
    ga[CA_BYTES / 2u] = 1u;   /* single-cell seed at center */
    use_a = 1u;               /* cur = ga */

    for (gen = 0; gen < (uint16_t)CA_GATE_GENS; gen++) {
        uint8_t rule = (gen < (uint16_t)(CA_GATE_GENS / 2u)) ? CA_RULE_90 : CA_RULE_110;
        uint8_t *s = use_a ? ga : gb;
        uint8_t *d = use_a ? gb : ga;
        ca_step(s, d, rule);
        crc   = ca_crc16_row(crc, d);
        use_a ^= 1u;
    }
    return crc;
}

#endif /* CA1D_H */
