// Bit-Serial CRC Wall (#105) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster D. Re-stresses patch 0010 (coalesce-rotate-Ac): a
// DEFAULT-8-BIT (not accum-gated) register-coalescer miscompile where two shift/rotate-referenced
// values were merged into the A-only `Ac` class, stranding a loop-carried CRC byte in Y while the
// back-edge ROL read a stale A. It was found by ONE inlined CRC16 bit loop under register pressure.
//
// ESCALATION: compute CRC-8, CRC-16 AND CRC-32 **bit-serially** (not table-driven — that is the
// whole point; #40 crctex used a ROM table and never forms the shift-register rotate loop), all
// THREE interleaved in one inner bit loop so three loop-carried shift registers + three poly
// constants are live simultaneously → maximal register pressure, exactly the condition that tempts
// the coalescer into the bad `Ac` join. This bug is 8-bit-only, so the DEFAULT build is the
// load-bearing leg (invisible to every +mos-a16/+mos-xy16 gate).
//
// DIFFERENTIAL: integer-exact — bit-serial CRC is pure shift/xor, bit-identical host vs target. A
// coalescer strand corrupts a loop-carried register → the folded CRC diverges (on default 8-bit).
// WIDTH DISCIPLINE: explicit uint8/16/32; no bare int; no float; no table.
// See docs/plans/2026-07-02-105-snes-crcwall.md.

#ifndef CRCWALL_H
#define CRCWALL_H

#include <stdint.h>

#define CW_POLY8   ((uint8_t)0x07u)         // CRC-8 (ATM)
#define CW_POLY16  ((uint16_t)0x1021u)      // CRC-16 (CCITT)
#define CW_POLY32  ((uint32_t)0x04C11DB7u)  // CRC-32 (MSB-first)

typedef struct { uint8_t c8; uint16_t c16; uint32_t c32; } CrcState;

// Process one byte through all three bit-serial CRCs, interleaved. Three loop-carried shift
// registers (crc<<1 with conditional poly-xor) live at once — the pressure that found 0010.
__attribute__((noinline))
static void cw_byte(CrcState *s, uint8_t byte) {
    s->c8  = (uint8_t)(s->c8 ^ byte);
    s->c16 = (uint16_t)(s->c16 ^ (uint16_t)((uint16_t)byte << 8));
    s->c32 = (uint32_t)(s->c32 ^ (uint32_t)((uint32_t)byte << 24));
    for (uint8_t b = (uint8_t)0u; b < (uint8_t)8u; b++) {
        s->c8  = (uint8_t)((s->c8  & (uint8_t)0x80u)
                           ? (uint8_t)(((uint8_t)(s->c8  << 1)) ^ CW_POLY8)
                           : (uint8_t)(s->c8 << 1));
        s->c16 = (uint16_t)((s->c16 & (uint16_t)0x8000u)
                           ? (uint16_t)(((uint16_t)(s->c16 << 1)) ^ CW_POLY16)
                           : (uint16_t)(s->c16 << 1));
        s->c32 = (uint32_t)((s->c32 & (uint32_t)0x80000000u)
                           ? (uint32_t)(((uint32_t)(s->c32 << 1)) ^ CW_POLY32)
                           : (uint32_t)(s->c32 << 1));
    }
}

// Single-width bit-serial CRC-8 for the display (loop-carried shift register, default-8-bit).
static inline uint8_t cw_crc8(uint8_t seed, uint8_t byte) {
    uint8_t c = (uint8_t)(seed ^ byte);
    for (uint8_t b = (uint8_t)0u; b < (uint8_t)8u; b++)
        c = (uint8_t)((c & (uint8_t)0x80u) ? (uint8_t)(((uint8_t)(c << 1)) ^ CW_POLY8) : (uint8_t)(c << 1));
    return c;
}

// Marble cell colour 0..3 from a bit-serial CRC-8 of (cx, cy, phase).
static inline uint8_t cw_cell_color(uint8_t cx, uint8_t cy, uint8_t phase) {
    uint8_t c = cw_crc8((uint8_t)0xA5u, (uint8_t)(cx + phase));
    c = cw_crc8(c, (uint8_t)(cy * (uint8_t)3u));
    c = cw_crc8(c, (uint8_t)(cx ^ cy ^ phase));
    return (uint8_t)((uint8_t)((c >> 6) ^ (c >> 1)) & (uint8_t)3u);
}

static inline uint16_t cw_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ v);
}

// --------------------------------------------------------------------------
// Differential gate: hash CW_N deterministic bytes through all three bit-serial CRCs, fold.
// --------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 96u
#endif

static uint16_t crcwall_gate_crc(void) {
    CrcState s;
    s.c8 = (uint8_t)0xFFu; s.c16 = (uint16_t)0xFFFFu; s.c32 = (uint32_t)0xFFFFFFFFu;
    uint16_t lcg = (uint16_t)0xACE1u;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        lcg = (uint16_t)(lcg * (uint16_t)25173u + (uint16_t)13849u);
        cw_byte(&s, (uint8_t)(lcg >> 8));
    }
    // Fold all three CRC registers into 16 bits (each must be correct or h diverges).
    uint16_t h = (uint16_t)0u;
    h = cw_fold(h, (uint16_t)s.c8);
    h = cw_fold(h, s.c16);
    h = cw_fold(h, (uint16_t)(s.c32 & (uint32_t)0xFFFFu));
    h = cw_fold(h, (uint16_t)(s.c32 >> 16));
    return h;
}

#endif /* CRCWALL_H */
