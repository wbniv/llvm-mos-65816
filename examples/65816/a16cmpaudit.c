// #321 Phase-3 differential-audit harness for the WHOLE native 16-bit compare
// surface — the "harden" half of the indexed-compares plan, now exercising the new
// RHS-indexed fold (`cmp (zp)`, CMPIndir16) alongside every prior compare form.
//
// Matrix: 8 predicates {ULT,UGT,ULE,UGE,EQ,NE, SLT, SGE} x {as-value, as-branch} x
// RHS operand shapes {register, immediate, global, global-array[k] (indirect fold),
// pointer[k] (indirect fold), stack-array[k]} + the LHS-indexed control, swept over
// boundary values {0x0000,0x00FF,0x0100,0x7FFF,0x8000,0xFFFF, equal, equal-high-byte}.
// Each outcome folds into a rolling 16-bit checksum (acc*31 + bit, mod 0x10000).
//
// The index `k` is volatile so each `V[k]`/`PV[k]`/`sa[k]` is a real runtime load;
// the arrays are non-volatile so each single-use load on a compare RHS is foldable
// (the high-byte-differing values 0x0100/0x12FF/0x8000 prove all 16 bits compare).
//
// Differential: host == default(8-bit) == +mos-a16, on MAME + bsnes-jg, and the
// +mos-a16 build is -verify-machineinstrs clean. The host oracle (the baked WANT in
// dev/a16cmpaudit.sh) is reproducible by host-compiling THIS file:
//     cc -DHOST_ORACLE -o /tmp/o examples/65816/a16cmpaudit.c && /tmp/o
// See docs/plans/2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md.
#ifdef HOST_ORACLE
#include <stdio.h>
#endif

#define NV 8
unsigned short V[NV] = {0x0000, 0x00FF, 0x0100, 0x7FFF, 0x8000, 0xFFFF, 0x1234, 0x12FF};
unsigned short G;
unsigned short *PV = V;
volatile unsigned char k;          // volatile index -> a genuine runtime arr[k] load
volatile unsigned short corpus_result;

static unsigned short fold(unsigned short acc, unsigned bit) {
  return (unsigned short)((unsigned)acc * 31u + bit);
}

// Eight predicates over (a,b): the four unsigned orderings, equality/inequality, and
// two signed orderings (the eor #$8000 + cmp path). Folded as 0/1 outcomes so any
// single mis-compare perturbs the checksum.
#define P8(a, b, out)                                            \
  do {                                                           \
    out = fold(out, (unsigned)((a) < (b)));                      \
    out = fold(out, (unsigned)((a) > (b)));                      \
    out = fold(out, (unsigned)((a) <= (b)));                     \
    out = fold(out, (unsigned)((a) >= (b)));                     \
    out = fold(out, (unsigned)((a) == (b)));                     \
    out = fold(out, (unsigned)((a) != (b)));                     \
    out = fold(out, (unsigned)((short)(a) < (short)(b)));        \
    out = fold(out, (unsigned)((short)(a) >= (short)(b)));       \
  } while (0)

int main(void) {
  unsigned short r = 0;
  unsigned short sa[NV];
  for (unsigned char i = 0; i < NV; i++)
    sa[i] = V[i];

  for (unsigned char i = 0; i < NV; i++) {
    unsigned short lhs = V[i];           // LHS register-resident
    for (unsigned char j = 0; j < NV; j++) {
      k = j;                             // volatile -> forces a runtime index
      unsigned short rr = V[j];          // RHS register
      G = V[j];                          // RHS global

      P8(lhs, rr, r);                    // reg  vs reg
      P8(lhs, G, r);                     // reg  vs global
      P8(lhs, V[k], r);                  // reg  vs global-array[k]   <- indirect fold
      P8(lhs, PV[k], r);                 // reg  vs pointer[k]        <- indirect fold
      P8(lhs, sa[k], r);                 // reg  vs stack-array[k]
      P8(V[k], lhs, r);                  // LHS-indexed vs reg (control: swaps to LHS)

      if (lhs < V[k])    r = fold(r, 0xA1);   // as-branch: RHS-indexed fold
      if (lhs >= PV[k])  r = fold(r, 0xB2);   // as-branch: RHS pointer-indexed
      if (lhs == sa[k])  r = fold(r, 0xC3);   // as-branch: stack-array EQ
      if (V[k] > lhs)    r = fold(r, 0xD4);   // as-branch: LHS-indexed control
    }
    P8(lhs, (unsigned short)0x0000, r);  // immediate RHS, boundary
    P8(lhs, (unsigned short)0x8000, r);
    P8(lhs, (unsigned short)0xFFFF, r);
  }

  corpus_result = r;
#ifdef HOST_ORACLE
  printf("0x%04X\n", (unsigned)corpus_result);
  return 0;
#else
  for (;;) {
  }
#endif
}
