// #320 Increment 3 — runtime far-pointer dereference via 65816 indirect-long.
//
// Increment 2b (far-bank1.c) proved a far read across a ROM bank boundary, but
// its address was a LINK-TIME constant that lowers to absolute-long (lda $018000,
// opcode AF). This program proves the other half: a far pointer whose 24-bit
// address is computed at RUNTIME — laundered through a volatile so it can't fold
// back to absolute-long — dereferenced via `lda [dp]` (opcode A7). `lda [dp]`
// reads a 3-byte (lo,hi,bank) pointer from the zero page; the pointer's 4 bytes
// live in a contiguous Imag32 ZP quad (__rcN..__rcN+3) that the register
// allocator keeps adjacent, so [dp] reads bytes N,N+1,N+2 as the 24-bit address.
//
// Needs +mos-a16: a runtime far pointer is a 32-bit VALUE, and 32-bit value
// legalization (the byte->word->long compose into Imag32) exists only under
// +mos-a16. The far MACHINERY (Imag32, [dp]) is itself a16-independent; the
// 32-bit value is not — so the default (8-bit) build legitimately can't compile
// a runtime far deref, and this gate is host-expected == +mos-a16 on both
// emulators (plus the disasm gate), not the usual 4-way differential.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os far_indir.c
// Built (64 KiB) + booted in MAME and bsnes-jg by dev/far_indir.sh
// (host: dev/run.sh far_indir). See docs/plans/2026-06-20-320-far-pointer-runtime.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Sentinel byte in ROM bank $01 (so the read genuinely needs the bank byte). It
// is addressed as a NEAR symbol (16-bit low address) but placed in bank $01 by
// the snes-far linker (.far_rodata -> rom_1 @ $018000); we OR in the bank ($01)
// at runtime to form the full 24-bit far address.
__attribute__((section(".far_rodata"))) const uint8_t bank1_sentinel = 0xA9;

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders the 24-bit far address to a runtime value so the dereference cannot
// constant-fold back to absolute-long (it must stay an indirect-long [dp]).
volatile uint32_t opaque_addr;

int main(void) {
  // Build the 24-bit far address of bank1_sentinel at RUNTIME: bank $01 in the
  // high byte, the symbol's near (low-16) address in the low two bytes.
  opaque_addr = ((uint32_t)1 << 16) | (uint16_t)(uintptr_t)&bank1_sentinel;
  uint32_t a = opaque_addr;                          // opaque -> no fold
  FAR const uint8_t *fp = (FAR const uint8_t *)a;    // inttoptr -> runtime far ptr
  corpus_result = *fp ^ 0x5A;                        // lda [dp]; 0xA9 ^ 0x5A = 0xF3
  for (;;) __asm__ volatile("wai");
}
