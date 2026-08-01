// #320 Increment 3 (3b) — near->far address-space cast (AS0 -> AS2), then runtime
// dereference. A NEAR (16-bit, bank $00) pointer is cast to a far (addrspace 2)
// pointer; the cast zero-extends the 16-bit near address to the 32-bit far value
// with bank byte $00 (correct for SNES bank-$00 data). The resulting far pointer
// is a RUNTIME value (the near address is laundered through a volatile so the
// whole thing can't constant-fold), so it dereferences via 65816 indirect-long
// `lda [dp]` (opcode A7) reading bank $00.
//
// Needs +mos-a16: the far pointer is a 32-bit value (see far_indir.c). The gate
// is host-expected == +mos-a16 on both emulators; there is no default leg.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os far_cast.c
// Built + booted in MAME and bsnes-jg by dev/far_cast.sh (host: dev/run.sh far_cast).
// See docs/plans/2026-06-20-320-far-pointer-runtime.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Sentinel byte in bank $00 (ordinary near rodata).
static const uint8_t near_sentinel = 0xA9;

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders the near address to a runtime value so the cast+deref can't fold.
volatile uint16_t opaque_near;

int main(void) {
  opaque_near = (uint16_t)(uintptr_t)&near_sentinel;
  const uint8_t *np = (const uint8_t *)(uintptr_t)opaque_near; // runtime near ptr (AS0)
  FAR const uint8_t *fp = (FAR const uint8_t *)np;             // addrspacecast AS0->AS2
  corpus_result = *fp ^ 0x5A;                                  // lda [dp] (bank $00); 0xA9 ^ 0x5A = 0xF3
  for (;;) __asm__ volatile("wai");
}
