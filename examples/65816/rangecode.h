// Range Coder (#86) — shared, portable logic header.
//
// Stresses: binary arithmetic (range) coding — the interval split
//   bound = (range >> PBITS) * prob        → G_LSHR (>>PBITS) + __mulsi3 (32-bit mul)
// and the byte-wise renormalization carry loop
//   while (range < TOP) { out ^= (low >> 24); low <<= 8; range <<= 8; }  → G_LSHR/G_SHL 32-bit
// A 32-bit range/low with a multiply-driven interval and a shift-renormalize loop — the
// exact shape of a real range coder. Distinct from #67 huffman (table/bit-length codes,
// no multiply-interval) and #49 lzdec (match/literal copy, no arithmetic coding).
//
// WIDTH DISCIPLINE: uint32_t range/low, uint16_t prob/index. No bare int.
// DIFFERENTIAL: exact integer arithmetic coding — bit-identical host vs 65816. Any wrong
// 32-bit product, shift, or carry in the renormalize loop diverges the coded stream fold.
//
// See docs/plans/2026-07-01-86-snes-rangecode.md.

#ifndef RANGECODE_H
#define RANGECODE_H

#include <stdint.h>

#define RC_PBITS 12u                         // probability precision (0..4096)
#define RC_TOP   ((uint32_t)0x01000000u)     // renormalize threshold (2^24)
#ifndef RC_GATE_N
#define RC_GATE_N 200u                       // symbols encoded in the gate
#endif

// xorshift16 for a deterministic symbol/probability stream.
static inline uint16_t rc_xs16(uint16_t s) {
    s ^= (uint16_t)(s << 7); s ^= (uint16_t)(s >> 9); s ^= (uint16_t)(s << 8); return s;
}

typedef struct {
    uint32_t low;
    uint32_t range;
    uint16_t out_fold;   // rolling fold of emitted bytes (stands in for an output buffer)
} RangeEnc;

static inline void rc_init(RangeEnc *e) {
    e->low = 0u; e->range = 0xFFFFFFFFu; e->out_fold = 0u;
}

// Emit the top byte during renormalization (folded, not buffered).
static inline void rc_emit(RangeEnc *e, uint8_t b) {
    e->out_fold = (uint16_t)((uint16_t)((e->out_fold << 3) | (e->out_fold >> 13)) ^ (uint16_t)b);
}

// Encode one binary symbol `bit` with P(bit==0) = prob/4096.
static inline void rc_encode_bit(RangeEnc *e, uint8_t bit, uint16_t prob) {
    // interval split: the multiply-driven bound (the codegen corner)
    uint32_t bound = (uint32_t)((e->range >> RC_PBITS) * (uint32_t)prob);   // G_LSHR + __mulsi3
    if (bit == 0u) {
        e->range = bound;
    } else {
        e->low = (uint32_t)(e->low + bound);
        e->range = (uint32_t)(e->range - bound);
    }
    // byte-wise renormalization carry loop
    while (e->range < RC_TOP) {                        // G_LSHR compare
        rc_emit(e, (uint8_t)(e->low >> 24));           // top byte out
        e->low = (uint32_t)(e->low << 8);              // 32-bit G_SHL
        e->range = (uint32_t)(e->range << 8);
    }
}

// ------------------------------------------------------------------
// Gate CRC: encode RC_GATE_N model-driven bits, fold the output + final state.
// ------------------------------------------------------------------
static uint16_t rangecode_gate_crc(void) {
    RangeEnc e; rc_init(&e);
    uint16_t s = 0xACE1u;
    uint16_t prob = 2048u;   // adaptive-ish probability, updated each symbol
    uint16_t i;
    for (i = 0u; i < (uint16_t)RC_GATE_N; i++) {
        s = rc_xs16(s);
        uint8_t bit = (uint8_t)(s & 1u);
        rc_encode_bit(&e, bit, prob);
        // simple binary adaptation: nudge prob toward the observed bit
        if (bit == 0u) prob = (uint16_t)(prob + (uint16_t)((4096u - prob) >> 5));
        else           prob = (uint16_t)(prob - (uint16_t)(prob >> 5));
        if (prob < 32u) prob = 32u;
        if (prob > 4064u) prob = 4064u;
    }
    // flush a few bytes
    uint8_t k;
    for (k = 0u; k < 4u; k++) { rc_emit(&e, (uint8_t)(e.low >> 24)); e.low = (uint32_t)(e.low << 8); }
    uint16_t h = e.out_fold;
    h = (uint16_t)(h ^ (uint16_t)(e.range & 0xFFFFu) ^ (uint16_t)(e.range >> 16));
    h = (uint16_t)(h ^ prob);
    return h;
}

#endif /* RANGECODE_H */
