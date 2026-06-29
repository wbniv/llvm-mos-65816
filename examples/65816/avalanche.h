// #22 SNES compiler stress-test — 64-BIT INTEGER hash / avalanche kernel.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/avalanche.c), the corpus
// slice (examples/snes/corpus/avalanche_sim.c) and the host oracle (tools/avalanche-sim.c).
//
// Why this demo exists: every Round-1 demo tops out at 32-bit arithmetic. NONE use `uint64_t`. This
// one mixes 64-bit integers, so on the 65816 (a 16-bit machine) every operation is a multi-limb
// libcall over four 16-bit words: __muldi3 (64x64->64 multiply), __lshrdi3/__ashldi3 (64-bit shifts,
// including variable counts and counts >= 32 that cross the 32-bit limb boundary), __udivdi3 (64-bit
// divide), __adddi3, and 64-bit xor. That whole family is otherwise UNTESTED by the battery.
//
// BIT-EXACT DIFFERENTIAL — and it's the easy kind: 64-bit integer ops are EXACT (no rounding), so a
// conforming 4-limb implementation on the 65816 must produce results IDENTICAL to host x86 (where
// uint64_t is native), bit for bit. Any limb-carry / wide-shift / div miscompile corrupts the hash
// and the gate CRC diverges immediately.
//
// The hash is splitmix64 (the canonical 64-bit mixer) plus a high-fold `^ (x >> 32)` so the kernel
// exercises BOTH shift regimes: counts < 32 (within a limb) and a count == 32 (whole-limb), the two
// distinct codegen paths a wide-shift bug tends to live in.
#ifndef AVALANCHE_H
#define AVALANCHE_H

#include <stdint.h>

// 64-bit mixer: splitmix64 finalizer + a high-fold. Two __muldi3, shifts of 30/27/31 (<32) and 32
// (==32), plus __adddi3 and 64-bit xor. Pure function — same bits on host (native u64) and target
// (4x16 libcalls).
static inline uint64_t h64_mix(uint64_t x) {
  x += (uint64_t)0x9E3779B97F4A7C15ULL;                 // __adddi3
  x = (x ^ (x >> 30)) * (uint64_t)0xBF58476D1CE4E5B9ULL; // >>30 (<32) + __muldi3
  x = (x ^ (x >> 27)) * (uint64_t)0x94D049BB133111EBULL; // >>27 (<32) + __muldi3
  x = x ^ (x >> 31);                                     // >>31 (<32)
  x = x ^ (x >> 32);                                     // >>32 (==32) — whole-limb shift path
  return x;
}

// Avalanche column: hash of `seed` with input bit i flipped. The `(uint64_t)1 << i` is a 64-bit
// shift by a RUNTIME count (0..63) — the variable-count __ashldi3 path, a codegen corner of its own.
// Output bit j of the result is cell (i,j) of the avalanche matrix: for a good mixer ~half the
// output bits flip when ANY single input bit flips, so the 64x64 matrix is ~50% dense with no
// structure — which is exactly what a correct 64-bit implementation must reproduce on the console.
static inline uint64_t h64_avalanche_col(uint64_t seed, uint8_t i) {
  uint64_t flipped = seed ^ ((uint64_t)1 << i);          // variable-count __ashldi3
  return h64_mix(flipped);
}

// 5-bit-per-channel palette for the matrix. Cleared bits are black; a set output bit in row j gets a
// hue that cycles with j (a rainbow down the output-bit axis), so the shimmering ~50%-dense field
// reads as colour bands rather than monochrome static. `phase` rotates the hue for the colour cycle.
static inline void h64_palette(uint8_t idx, uint8_t nh, uint8_t *r5, uint8_t *g5, uint8_t *b5) {
  if (idx == 0) { *r5 = 0; *g5 = 0; *b5 = 0; return; }   // cleared bit -> black
  uint8_t h = (uint8_t)((idx - 1u) % (nh ? nh : 1));      // 0..nh-1 hue bucket
  // simple 6-band rainbow approximation in 5-bit channels
  uint8_t seg = (uint8_t)(h * 6u / (nh ? nh : 1));
  uint8_t t = (uint8_t)((uint16_t)(h * 6u % (nh ? nh : 1)) * 31u / (nh ? nh : 1));
  switch (seg) {
    case 0:  *r5 = 31;      *g5 = t;       *b5 = 0;  break;
    case 1:  *r5 = (uint8_t)(31 - t); *g5 = 31; *b5 = 0; break;
    case 2:  *r5 = 0;       *g5 = 31;      *b5 = t;  break;
    case 3:  *r5 = 0;  *g5 = (uint8_t)(31 - t); *b5 = 31; break;
    case 4:  *r5 = t;       *g5 = 0;       *b5 = 31; break;
    default: *r5 = 31; *g5 = 0; *b5 = (uint8_t)(31 - t); break;
  }
}

// CRC16-CCITT (XModem) — identical routine to julia_crc / mf_crc.
static inline uint16_t h64_crc(const uint8_t *p, uint16_t len) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < len; k++) {
    crc ^= (uint16_t)((uint16_t)p[k] << 8);
    for (uint8_t b = 0; b < 8; b++) {
      if (crc & 0x8000) crc = (uint16_t)((uint16_t)(crc << 1) ^ 0x1021);
      else              crc = (uint16_t)(crc << 1);
    }
  }
  return crc;
}

#define H64_GATE_N 256u   /* hash iterations folded by the gate */

// Differential anchor: chain H64_GATE_N splitmix64 steps, folding each 64-bit output through a
// 64-bit xor, an add of a shifted copy, and a 64-bit DIVIDE by a runtime divisor (forcing __udivdi3
// rather than a constant-folded reciprocal). Then fold the four 16-bit words of the accumulator into
// a 16-bit CRC, using a VARIABLE shift count (w*16 = 0/16/32/48) so the fold itself spans both the
// <32 and >=32 shift regimes. All exact-integer, far-pointer-free -> full 5-way bar, bit-for-bit
// host == target. Issues well over a thousand 64-bit libcalls, finishing inside the corpus budget.
static inline uint16_t h64_gate_crc(void) {
  uint64_t s = (uint64_t)0x0123456789ABCDEFULL;
  uint64_t acc = (uint64_t)0xFFFFFFFFFFFFFFFFULL;
  for (uint16_t k = 0; k < (uint16_t)H64_GATE_N; k++) {
    s = h64_mix(s);                       // 2 __muldi3 + shifts + xor + add
    acc ^= s;                             // 64-bit xor
    acc = acc + (s >> 17);                // __adddi3 + __lshrdi3 (const 17)
    uint64_t d = s | (uint64_t)1;         // odd, non-zero divisor
    acc = acc ^ (acc / d);                // __udivdi3 (runtime divisor)
  }
  uint16_t h = 0;
  for (uint8_t w = 0; w < 4; w++) {
    uint16_t word = (uint16_t)(acc >> (uint8_t)(w * 16));   // variable-count __lshrdi3 (0/16/32/48)
    h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ word);
  }
  return h;
}

#endif /* AVALANCHE_H */
