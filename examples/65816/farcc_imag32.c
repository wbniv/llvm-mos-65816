// #320 Increment 4 Phase 2 — far-pointer CALLING CONVENTION, variant (a) Imag32.
//
// Inc 3 made a far (addrspace 2) pointer a usable 32-bit VALUE (deref/cast/arith);
// Inc 4 Phase 1 made a far CALL (JSL/RTL). This is the missing third piece: a far
// pointer that CROSSES a call boundary — passed as an argument and returned as a
// result. Before this change that crashed in call lowering:
//
//   %6:_(s16) = G_UNMERGE_VALUES %5:_(p2)
//   *** Bad machine code: G_UNMERGE_VALUES scalar source does not match destination
//
// because CC_MOS sized EVERY pointer at 16 bits (CCIfPtr -> RS#) and a 32-bit p2
// did not fit. Variant (a) adds a gated far-ptr rule that assigns the whole 32-bit
// pointer to one Imag32 (RL) quad — the width-extension of how near pointers pass
// in RS pairs. Selected by -target-feature +mos-farcc-imag32; with no farcc
// feature, default codegen is byte-identical (the rule never matches).
//
// The round-trip exercises BOTH directions of the far-ptr CC across REAL calls
// (both noinline, so neither is inlined away):
//   * make_far_ptr() RETURNS a 32-bit far pointer  (far-ptr return CC -> RL)
//   * deref_far()     RECEIVES it as an argument    (far-ptr arg CC    -> RL)
// If any of the 4 pointer bytes were dropped crossing a call, the dereference
// would read the wrong 24-bit address and the value would not round-trip.
//
// Needs +mos-a16 (like far_indir.c): forming a far pointer from a runtime integer
// (inttoptr) and dereferencing it ([dp]) is 32-bit value legalization, which lives
// under +mos-a16. The CC machinery itself (RL quad, COPYs) is a16-independent.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 +mos-farcc-imag32 -Os
// Built (64 KiB, banks $00+$01) + booted in MAME and bsnes-jg by dev/farcc_imag32.sh
// (host: dev/run.sh farcc_imag32). See
// docs/plans/2026-06-20-320-far-pointer-cc-build-all-variants.md (Phase 2, A0).

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Sentinel byte in ROM bank $01 (so the read genuinely needs the bank byte to be
// carried intact through both calls). Addressed as a NEAR symbol (16-bit low
// address) but placed in bank $01 by the snes-far linker (.far_rodata -> rom_1).
__attribute__((section(".far_rodata"))) const uint8_t bank1_sentinel = 0xA9;

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders the 24-bit far address to a runtime value so neither call can be
// constant-folded / propagated away (the pointer must really travel in registers).
volatile uint32_t opaque_addr;

// noinline => genuinely RETURNS a 32-bit far pointer across a call boundary. This
// is the far-pointer RETURN convention (variant a: the quad lands in RL).
__attribute__((noinline)) static FAR const uint8_t *make_far_ptr(uint32_t a) {
  return (FAR const uint8_t *)a; // inttoptr: runtime 32-bit far pointer
}

// noinline => genuinely RECEIVES a far pointer as an argument across a call, then
// dereferences it (lda [dp]). This is the far-pointer ARGUMENT convention.
__attribute__((noinline)) static uint8_t deref_far(FAR const uint8_t *p) {
  return *p;
}

int main(void) {
  // Build the 24-bit far address of bank1_sentinel at RUNTIME: bank $01 high,
  // the symbol's near (low-16) address in the low two bytes.
  opaque_addr = ((uint32_t)1 << 16) | (uint16_t)(uintptr_t)&bank1_sentinel;

  FAR const uint8_t *fp = make_far_ptr(opaque_addr); // far ptr RETURNED across a call
  corpus_result = deref_far(fp) ^ 0x5A;              // far ptr PASSED across a call; 0xA9^0x5A=0xF3
  for (;;) {                                         // stay alive while MAME settles
  }
}
