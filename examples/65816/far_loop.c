// #321 — a far (addrspace 2) pointer used as a LOOP INDUCTION VARIABLE.
//
// THE BUG this gates: a far pointer carried across a loop back-edge
// (`for(;…;p++) *p=…`) forms a `G_PHI` of a far (p2) pointer. The MOS
// legalizer made G_PHI legal only for {s1,s8,p0,p1} — NOT the 32-bit far
// pointer p2 — so the backend ABORTED: "unable to legalize instruction:
// %N:_(p2) = G_PHI ...". Valid C the compiler should never choke on. The fix
// custom-legalizes a far-pointer phi to an s32 phi (G_PTRTOINT each incoming
// value in its predecessor, G_INTTOPTR the result back to p2 after the phi) —
// the same ptrtoint/inttoptr bridge far load/store and legalizePtrAdd use.
//
// IMPORTANT — keeping the phi alive: at -Os/-O2 LLVM's indvars/LSR rewrites a
// plain unit-stride far-ptr IV into an integer index (`hi + i`, a G_PTR_ADD),
// dissolving the phi — so a naive `p++` loop compiles even WITHOUT the fix and
// would not exercise it. This test advances by a RUNTIME stride (`p += s`, with
// s==1 at runtime but opaque to the optimizer), which forces the far-ptr phi to
// survive to the legalizer at every -O level. Both the write and the read-back
// loops use a far-ptr IV, so legalizePhi is exercised on the store AND the load
// path. (The well-gated WORKAROUND for user code is the index form `ptr[i]`.)
//
// The read-back SUM is value-sensitive: a wrong-bank store (bank byte dropped)
// reads back as uninitialized, changing corpus_result. Region lives in HIGH
// WRAM ($7E2000), reachable only by 24-bit far addressing. Needs +mos-a16
// (a runtime far pointer is a 32-bit value).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os far_loop.c
// Built + booted in MAME and bsnes-jg by dev/far_loop.sh (host: dev/run.sh far_loop).
// See docs/plans/2026-06-26-fix-the-far-pointer-g-phi-p2-backend-gap.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// High WRAM (bank $7E) — only 24-bit far addressing can reach it.
static FAR uint8_t *const hi = (FAR uint8_t *)0x7E2000u;

volatile uint16_t n;     // runtime trip count (a real loop, not unrolled away)
volatile uint16_t step;  // runtime stride -> the far-ptr IV phi survives to the legalizer

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

int main(void) {
  n = 50;               // runtime trip count
  step = 1;             // runtime stride (==1, but a volatile load -> opaque to the optimizer)
  uint16_t cnt = n;     // 50
  uint16_t s = step;    // 1 at runtime, but opaque -> p stays a genuine far-ptr IV

  // far-pointer INDUCTION VARIABLE write loop (the G_PHI(p2) shape that aborted).
  FAR uint8_t *p = hi;
  for (uint16_t i = 0; i < cnt; i++, p += s)
    *p = (uint8_t)i;  // hi[i] = i, via a far-ptr IV store (sta [dp])

  // far-pointer INDUCTION VARIABLE read-back loop, summed (value-sensitive).
  FAR uint8_t *q = hi;
  uint8_t acc = 0;
  for (uint16_t i = 0; i < cnt; i++, q += s)
    acc += *q;  // sum hi[0..49] via a far-ptr IV load (lda [dp])

  corpus_result = acc;  // sum(0..49) = 1225 -> 0xC9 iff the IV stores hit bank $7E
  for (;;) __asm__ volatile("wai");
}
