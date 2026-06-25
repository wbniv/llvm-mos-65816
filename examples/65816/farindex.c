// #320 "far data > 2 banks" GATE — a far (addrspace 2) array indexed across THREE bank
// boundaries, read by runtime 24-bit far loads (`lda [dp]`, A7), differential-verified.
// Driven by `dev/run.sh farindex`. Plan:
// docs/plans/2026-06-26-formalize-far-data-2-banks-into-a-dedicated-passin.md
//
// History: this was the cross-bank far-subscript BUG repro. The defect — a far array index
// whose `index*elemsize` crosses a 64 KiB boundary truncated to 16 bits and mis-addressed the
// bank — is FIXED in patches/llvm-mos/0001 (clang `CGExpr.cpp` promotes the GEP index to the
// base pointer's per-address-space width, 32-bit for AS2, so the offset carries into the bank
// byte). With the fix the three reads below land in banks $C1/$C2/$C3 correctly, so the repro is
// now promoted to a passing gate. `dev/run.sh k_trig32lut` corroborates on the real ~200 KiB
// libfixmath sin LUT (banks $C1..$C4).
//
// a16-only: a runtime far pointer is a 32-bit value (s32 legalization is +mos-a16-gated), like
// every other far_* test. The differential is host == +mos-a16 on MAME + bsnes-jg.
//
// `tbl` spans banks $C1..$C3 (98304 x uint16 = 192 KiB), supplied on the TARGET by a generated
// .far_rodata asm (tools/gen-farindex-lut-asm.py). It is declared extern+incomplete so the mos
// frontend's 16-bit size_t never sees a >64 KiB C array.
//
// VALUE CONTRACT (host == target, must match the generator):  tbl[i] = (i + (i >> 16)) & 0xFFFF.
// The `+ (i>>16)` term makes the value depend on the element's BANK ordinal, so a mis-carried
// far read returns a DIFFERENT value — each probe independently regress-detects (a plain
// `i & 0xFFFF` would let the bank-$C3 probe alias its own bug). The three probe indices land in
// three distinct banks (tbl based at $C10000):
//     tbl[100]    off $000C8 -> $C100C8  bank $C1  (within-first-bank control)  -> 0x0064
//     tbl[50000]  off $186A0 -> $C286A0  bank $C2                               -> 0xC350
//     tbl[90000]  off $2BF20 -> $C3BF20  bank $C3                               -> 0x5F91 (90001)
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

#ifndef HOST
extern const FAR uint16_t tbl[];
#define READ(i) ((uint16_t)tbl[(i)])
#else
// Host has no addrspace 2; reproduce the generator's closed form directly (no >64 KiB array).
#define READ(i) ((uint16_t)((uint32_t)(i) + ((uint32_t)(i) >> 16)))
#endif

// VOLATILE so the optimizer must do runtime 32-bit far-pointer arithmetic (-> lda [dp]), never
// constant-fold an index into a compile-time absolute-long. 100->$C1, 50000->$C2, 90000->$C3.
volatile int32_t i0 = 100, i1 = 50000, i2 = 90000;

static inline uint32_t fold(uint32_t acc, uint16_t v) {
  acc = (acc << 1) | (acc >> 31);  // rotate-left-1
  return acc ^ (uint32_t)v;
}

static uint32_t run(void) {
  uint32_t acc = 0;
  acc = fold(acc, READ(i0));  // bank $C1
  acc = fold(acc, READ(i1));  // bank $C2
  acc = fold(acc, READ(i2));  // bank $C3
  return acc;                 // golden 0x0001D8A1 (host oracle is the source of truth)
}

#ifdef HOST
#include <stdio.h>
int main(void) {
  printf("0x%08lX\n", (unsigned long)run());
  return 0;
}
#else
// target: write the checksum to WRAM and spin while the emulator settles.
volatile uint32_t corpus_result;
int main(void) {
  corpus_result = run();
  for (;;) {
  }
}
#endif
