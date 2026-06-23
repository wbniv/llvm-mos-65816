// #321 — 32-bit `long`/`int32_t` value differential. Driven by `dev/run.sh a16s32`.
// Plan: docs/plans/2026-06-23-321-32bit-long-verification.md
//
// Verifies the EXISTING s32 codegen (no compiler change). Under +mos-a16 an s32 is
// represented as 2x s16 (MOSLegalizerInfo) with 4x s8<->s32 (un)merge glue and
// libcalls for mul/div/variable-shift; the DEFAULT 8-bit build supports `long` too.
// So the differential is the full 4-way: host == default@MAME == +mos-a16@MAME ==
// +mos-a16@bsnes-jg.
//
// `compute()` folds every s32 hazard into a 32-bit `corpus_result` (XOR-accumulated,
// so a wrong byte anywhere flips it):
//   * a+b, a-b, a+1        -> the 2x s16 CARRY chain across the 16-bit boundary
//   * a*b                  -> __mulsi3 libcall
//   * a/b, a%b (guarded)   -> __udivsi3 / __umodsi3 libcall
//   * a<<5, a>>5, a>>8     -> shift legalization (const; >=8 byte/unmerge path)
//   * (int32_t)a >> 5      -> ARITHMETIC shift (sign-propagating)
//   * (b3<<24|..|b0)       -> 4x s8 -> s32 MERGE (legalizeMergeS32FromBytes)
//   * (uint16_t)hw         -> zero-extend s16 -> s32
//   * (int16_t)sw          -> sign-extend  s16 -> s32
//   * a==b, a<b, (s)a<(s)b -> s32 compare consumed as a VALUE (signed + unsigned)
//
// The SAME source computes the expected value on the host (uint32_t is 32-bit on
// both host and target), so `WANT` is exact by construction — see dev/a16s32.sh,
// which host-compiles this file with -DHOST_ORACLE to derive WANT.

#include <stdint.h>

// Laundered operands (volatile -> nothing folds to a constant; real s32 codegen).
volatile uint32_t a = 0x89ABCDEFu, b = 0x12345678u;
volatile uint8_t  b0 = 0xDEu, b1 = 0xADu, b2 = 0xBEu, b3 = 0xEFu;
volatile uint16_t hw = 0xF00Du;
volatile int16_t  sw = -12345;

volatile uint32_t corpus_result;

static void compute(void) {
  uint32_t r = 0;
  r ^= (uint32_t)(a + b);                         // 2x s16 carry
  r ^= (uint32_t)(a - b);
  r ^= (uint32_t)(a + 1u);                        // s32 +1 (byte-chain unmerge)
  r ^= (uint32_t)(a * b);                          // __mulsi3
  r ^= (uint32_t)(b ? a / b : a);                  // __udivsi3 (guarded /0)
  r ^= (uint32_t)(b ? a % b : a);                  // __umodsi3 (guarded /0)
  r ^= (uint32_t)(a << 5);                         // logical shift-left <8
  r ^= (uint32_t)(a >> 5);                         // logical shift-right <8
  r ^= (uint32_t)(a >> 8);                         // shift-right >=8 (byte path)
  // NB: the two int32_t lines below are *implementation-defined* (not UB) for a's
  // top-bit-set value: an arithmetic right shift of a negative (C 6.5.7) and the
  // out-of-range uint->int conversion (C 6.3.1.3p3). Both gcc (host oracle) and
  // clang/LLVM (target) define them identically (sign-propagating shift; modulo-2^32
  // conversion), which is exactly what the host==target differential checks — but it
  // is a consistency check, not a Standard-mandated value.
  r ^= (uint32_t)((int32_t)a >> 5);                // arithmetic shift-right
  r ^= ((uint32_t)b3 << 24) | ((uint32_t)b2 << 16) // 4x s8 -> s32 merge
       | ((uint32_t)b1 << 8) | (uint32_t)b0;
  r ^= (uint32_t)(uint16_t)hw;                     // zero-extend s16 -> s32
  r ^= (uint32_t)(int32_t)(int16_t)sw;             // sign-extend  s16 -> s32
  r ^= (uint32_t)(a == b);                          // s32 == as a value
  r ^= (uint32_t)(a < b);                           // unsigned < as a value
  r ^= (uint32_t)((int32_t)a < (int32_t)b);         // signed   < as a value
  corpus_result = r;
}

#ifdef HOST_ORACLE
#include <stdio.h>
int main(void) {
  compute();
  printf("0x%08lX\n", (unsigned long)corpus_result);
  return 0;
}
#else
int main(void) {
  compute();
  for (;;) {                                       // stay alive while MAME settles
  }
}
#endif
