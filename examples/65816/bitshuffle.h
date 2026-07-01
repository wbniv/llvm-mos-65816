// Shared, PURE bit-permutation "perfect shuffle" — host-linkable, no hardware.  Demo #54.
//
// The codegen corner: the **byte-swap / bit-reverse intrinsics** — __builtin_bswap32 (-> the compiler-rt
// libcall __bswapsi2) and __builtin_bitreverse32 (-> G_BITREVERSE, inline-lowered via `.lower()` at
// MOSLegalizerInfo.cpp:186 as a mask-swap cascade 0x5555.. / 0x3333.. / 0x0F0F.. then a byte reversal).
// Distinct from #25 (FFT) and #28 (Hilbert), which reverse bits by HAND in a shift loop — here the
// clang builtins take the generic-opcode -> legalizer path those hand-rolled loops never touch.
//
// The bit-reversal permutation of an N-bit index is an INVOLUTION (bitrev(bitrev(i)) == i), so the
// image scrambles into its bit-reversed (butterfly/perfect-shuffle) order and un-scrambles with the
// SAME operation — a clean "digital riffle shuffle" transition.  A byte-swap recolour runs while the
// image is held scrambled.
//
// WIDTH DISCIPLINE: both builtins operate on `uint32_t` = 32-bit on host AND target, so the result is
// bit-identical by construction (unlike the width-sensitive int/long bit-count builtins of #53).
// See docs/plans/2026-06-30-54-snes-bitshuffle.md.
#ifndef BITSHUFFLE_H
#define BITSHUFFLE_H

#include <stdint.h>

#ifndef SHUF_BITS
#define SHUF_BITS 8u              // 256-cell index space (a 16x16 grid); bit-reverse the low 8 bits
#endif

// 32-bit bit reversal.  On the target (mos-clang) this is __builtin_bitreverse32 -> the generic opcode
// G_BITREVERSE, inline-lowered by MOSLegalizerInfo.cpp:186 as a mask-swap cascade.  __builtin_bitreverse
// is a CLANG builtin (gcc lacks it), so the host oracle uses a portable SWAR reference that computes the
// bit-identical value — the differential then tests the target's G_BITREVERSE lowering against ground
// truth.  (bswap has __builtin_bswap32 on both compilers, so it needs no fallback.)
static inline uint32_t bitshuffle_bitrev32(uint32_t v) {
#if defined(__clang__)
    return __builtin_bitreverse32(v);
#else
    v = ((v & 0x55555555u) << 1) | ((v >> 1) & 0x55555555u);
    v = ((v & 0x33333333u) << 2) | ((v >> 2) & 0x33333333u);
    v = ((v & 0x0F0F0F0Fu) << 4) | ((v >> 4) & 0x0F0F0F0Fu);
    v = ((v & 0x00FF00FFu) << 8) | ((v >> 8) & 0x00FF00FFu);
    return (v << 16) | (v >> 16);
#endif
}

// Bit-reversal permutation of an N-bit index.  Reverse the full 32-bit word, then shift the reversed
// low-N bits back down.  Involution on [0, 2^N): bitshuffle_perm(bitshuffle_perm(i)) == i.
static inline uint16_t bitshuffle_perm(uint16_t i) {
    uint32_t r = bitshuffle_bitrev32((uint32_t)i);
    return (uint16_t)(r >> (32u - SHUF_BITS));
}

// Reversible byte-swap of a 32-bit token via __builtin_bswap32 (-> __bswapsi2).  bswap(bswap(t)) == t.
static inline uint32_t bitshuffle_bswap(uint32_t t) {
    return __builtin_bswap32(t);
}

// Per-cell colour while the image is held scrambled: byte-swap a (x,y,time) token, fold to 0..ncol-1.
static inline uint8_t bitshuffle_color(uint16_t x, uint16_t y, uint16_t t, uint8_t ncol) {
    uint32_t tok = ((uint32_t)(x & 0xFFu) << 24) | ((uint32_t)(y & 0xFFu) << 16)
                 | ((uint32_t)(t & 0xFFu) << 8) | 0xA5u;
    uint32_t s = __builtin_bswap32(tok);
    return (uint8_t)(((s >> 5) ^ (s >> 17)) % ncol);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t bitshuffle_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 256u
#endif

// Fold the FULL 32-bit bit-reversal and byte-swap of a spread input (both 16-bit halves) over GATE_N
// runtime indices, so every reversed/swapped bit affects the hash — a miscompile in G_BITREVERSE or
// the bswap lowering diverges.  Also fold the 8-bit permutation's involution round-trip
// (bitshuffle_perm(bitshuffle_perm(i)) must equal i), catching an asymmetric bit-reversal bug.  The
// spread input is built from constant shifts/XORs (no 32-bit multiply -> no incidental __mulsi3).
static uint16_t bitshuffle_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_N; i++) {
        uint32_t base = ((uint32_t)i << 17) ^ ((uint32_t)i << 6) ^ (uint32_t)(i * 5u) ^ 0x9E3779B9u;
        uint32_t vr = bitshuffle_bitrev32(base);          // G_BITREVERSE
        uint32_t vs = bitshuffle_bswap(base ^ 0x55AA33CCu);// __builtin_bswap32
        uint16_t p  = bitshuffle_perm(i);
        uint16_t pp = bitshuffle_perm(p);                 // involution: == i if correct
        h = bitshuffle_fold(h, (uint16_t)vr);
        h = bitshuffle_fold(h, (uint16_t)(vr >> 16));
        h = bitshuffle_fold(h, (uint16_t)vs);
        h = bitshuffle_fold(h, (uint16_t)(vs >> 16));
        h = bitshuffle_fold(h, (uint16_t)(p ^ (uint16_t)(pp << 8)));
    }
    return h;
}

#endif /* BITSHUFFLE_H */
