// Bit-Banged UART Eye (#108) — shared, portable logic header.
//
// Round 6 (harden-the-fixes), Cluster D (final). Re-stresses patch 0010 (coalesce-rotate-Ac): a
// DEFAULT-8-BIT (NOT accum-gated) register-coalescer miscompile that stranded a loop-carried byte
// while a back-edge rotate read a stale accumulator. This models a **software UART**: a byte is
// framed (start bit 0 + 8 data LSB-first + stop bit 1) and shifted OUT one bit at a time through a
// carry-rotated transmit register, while a receive register rotates each sampled bit IN — two
// loop-carried shift registers both rotated on every back edge (the 0010 pressure), inside a
// framing loop. A correct round-trip recovers the original byte (a built-in self-check).
//
// This bug is 8-bit-only, so the DEFAULT build is the load-bearing leg. DIFFERENTIAL: bit-banging is
// pure shift/rotate → bit-identical host vs target, and the TX→RX round-trip is the identity, so the
// gate folds `roundtrip(b) ^ b` as a witness (0 when correct). A coalescer strand corrupting a
// loop-carried register breaks the round-trip and diverges the CRC (default 8-bit). WIDTH DISCIPLINE:
// explicit uint8/uint16; no bare int; no float. See the plan.

#ifndef UARTEYE_H
#define UARTEYE_H

#include <stdint.h>

// Frame a byte into a 10-bit UART word: bit0 = start(0), bits1..8 = data LSB-first, bit9 = stop(1).
static inline uint16_t uart_frame(uint8_t b) {
    return (uint16_t)(((uint16_t)1u << 9) | ((uint16_t)b << 1));   // start bit is 0 (already clear)
}

// Bit-bang the 10-bit frame out of a carry-rotated TX register and into a carry-rotated RX register.
// Two loop-carried shift registers rotated on every iteration — the 0010 rotate-carry shape under
// pressure. Returns the recovered data byte (== b when correct).
__attribute__((noinline))
static uint8_t uart_roundtrip(uint8_t b) {
    uint16_t tx = uart_frame(b);
    uint16_t rx = (uint16_t)0u;
    for (uint8_t i = (uint8_t)0u; i < (uint8_t)10u; i++) {
        uint8_t bit = (uint8_t)(tx & (uint16_t)1u);                          // sample the line (LSB)
        tx = (uint16_t)(tx >> 1);                                            // rotate TX out
        rx = (uint16_t)((uint16_t)(rx >> 1) | (uint16_t)((uint16_t)bit << 9)); // rotate the bit into RX
    }
    return (uint8_t)((uint16_t)(rx >> 1) & (uint16_t)0xFFu);                 // deframe: drop start, take 8 data
}

// Return the serial line level (0/1) at sub-sample `s` (0..SUB-1) within bit `k` (0..9) of b's frame,
// for the display eye. LFSR-free; pure framing.
#define UART_SUB 4u   // sub-samples per bit
static inline uint8_t uart_level(uint8_t b, uint8_t bit_index) {
    uint16_t frame = uart_frame(b);
    return (uint8_t)((frame >> bit_index) & (uint16_t)1u);
}

static inline uint16_t ue_fold(uint16_t h, uint16_t v) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ v);
}

// ---------------------------------------------------------------------------------------------
// Differential gate: round-trip a deterministic byte stream; fold the recovered byte AND the
// round-trip witness (roundtrip(b) ^ b == 0 when correct). Also fold the intermediate frame words.
// ---------------------------------------------------------------------------------------------
#ifndef GATE_N
#define GATE_N 128u
#endif

static uint16_t uarteye_gate_crc(void) {
    uint16_t h = (uint16_t)0u;
    uint16_t seed = (uint16_t)0x55AAu;
    for (uint16_t i = (uint16_t)0u; i < (uint16_t)GATE_N; i++) {
        seed = (uint16_t)(seed * 25173u + 13849u);        // deterministic LCG
        uint8_t b = (uint8_t)(seed >> 7);
        uint8_t r = uart_roundtrip(b);
        h = ue_fold(h, (uint16_t)r);
        h = ue_fold(h, (uint16_t)((uint16_t)(uint8_t)(r ^ b)));   // round-trip witness: 0 when correct
        h = ue_fold(h, uart_frame(b));                            // fold the framed word too
    }
    return h;
}

// -------- ROM display: an oscilloscope eye pattern -------------------------------------------
#define UE_GRID 16u

#endif /* UARTEYE_H */
