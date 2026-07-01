// Shared, PURE bit-population "census" texture — host-linkable, no hardware.  Demo #53.
//
// The codegen corner: the **bit-population intrinsic family** — count-ones / count-leading-zeros /
// count-trailing-zeros / parity — which none of the first 52 demos ever emit.  Each cell's colour is a
// bit-count of a value built from its (x, y, time) coordinates, cycling through the four functions:
//   fn 0: __builtin_popcountll  -> the classic XOR/AND bit-fractal (Sierpinski-like)
//   fn 1: __builtin_clzll       -> concentric "bit-magnitude" bands
//   fn 2: __builtin_ctzll       -> ruler-sequence bands
//   fn 3: __builtin_parityll    -> a fine parity checker
// On the 65816 these route to the compiler-rt helpers __popcountdi2 / __clzdi2 / __ctzdi2 / __paritydi2
// and/or the inline G_CTPOP / G_CTLZ / G_CTTZ shift-tree lowering (MOSLegalizerInfo.cpp:308 `.lower()`).
//
// WIDTH DISCIPLINE (host int=32,long=64 / target int=16,long=32 must agree bit-for-bit):
//   The plain __builtin_popcount/clz/ctz take `int`/`unsigned` (32-bit host, 16-bit target) and the
//   `l` variants take `long` (64-bit host, 32-bit target) — BOTH mismatch across host/target, so their
//   results would legitimately diverge (a source portability defect, NOT a compiler bug).  The `ll`
//   variants take `long long` = 64-bit on BOTH, so the census is identical on host and target by
//   construction; any divergence in the differential is then a real codegen defect.  (The 32-bit
//   `__*si2` members of the same family are exercised by the identical lowering rule at s32 — see plan.)
//   clz/ctz of 0 is undefined, so every argument is forced non-zero (a set bit is OR-ed in).
// See docs/plans/2026-06-30-53-snes-bitcensus.md.
#ifndef BITCENSUS_H
#define BITCENSUS_H

#include <stdint.h>

// Per-cell bit-population census.  fn selects which intrinsic; all inputs widened to 64-bit so the
// result is width-identical host vs target.  Returns a small raw count (0..63) or parity (0/1).
static inline uint8_t bitcensus_cell(uint16_t x, uint16_t y, uint16_t t, uint8_t fn) {
    uint64_t a = (uint64_t)x;
    uint64_t b = (uint64_t)y;
    uint64_t c = (uint64_t)t;
    switch (fn & 3u) {
      case 0: {  // POPCOUNT: (x^y) spread across the word, time in the high lanes -> XOR bit-fractal
        uint64_t v = ((a ^ b) | (c << 20)) & 0x000FFFFFFFFFFFFFULL;
        return (uint8_t)__builtin_popcountll(v);
      }
      case 1: {  // CLZ: coords packed high so leading-zero count tracks magnitude -> concentric bands
        uint64_t v = (((a + c) << 32) | ((b + c) << 8) | 1ULL);   // | 1 forces non-zero (UB guard)
        return (uint8_t)__builtin_clzll(v);
      }
      case 2: {  // CTZ: (x&y)+time+1 low, a high bit set -> ruler-sequence trailing-zero bands
        uint64_t v = ((a & b) + c + 1ULL) | 0x8000000000000000ULL; // high bit forces non-zero
        return (uint8_t)__builtin_ctzll(v);
      }
      default: { // PARITY: fine checker
        uint64_t v = (a << 33) ^ (b << 7) ^ (c << 1) ^ 0x1ULL;
        return (uint8_t)__builtin_parityll(v);
      }
    }
}

// Map a raw census value to a 2bpp colour index (0..ncol-1).
static inline uint8_t bitcensus_color(uint8_t census, uint8_t ncol) {
    return (uint8_t)(census % ncol);
}

// ---------------------------------------------------------------------------------------------
// CRC fold + differential gate.

static inline uint16_t bitcensus_fold(uint16_t h, uint16_t x) {
    return (uint16_t)((((uint16_t)(h << 1)) | (uint16_t)((h >> 15) & 1u)) ^ x);
}

#ifndef GATE_N
#define GATE_N 200u
#endif

// Fold the census of all four intrinsics over GATE_N pseudo-coordinates.  x/y/t are runtime-derived
// so the bit-counts can't be constant-folded away; a miscompile in any of the four lowerings diverges.
static uint16_t bitcensus_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)GATE_N; i++) {
        uint16_t x = (uint16_t)(i * 5u + 1u);
        uint16_t y = (uint16_t)(i * 11u + 7u);
        uint16_t t = (uint16_t)(i >> 1);
        h = bitcensus_fold(h, (uint16_t)bitcensus_cell(x, y, t, 0u));
        h = bitcensus_fold(h, (uint16_t)bitcensus_cell(x, y, t, 1u));
        h = bitcensus_fold(h, (uint16_t)bitcensus_cell(x, y, t, 2u));
        h = bitcensus_fold(h, (uint16_t)bitcensus_cell(x, y, t, 3u));
    }
    return h;
}

#endif /* BITCENSUS_H */
