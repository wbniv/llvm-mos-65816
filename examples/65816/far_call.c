// #320 Increment 4 — far call (JSL/RTL): call a function in ANOTHER 64 KB bank.
//
// Inc 1-3 delivered far DATA (load/store/deref/arith). This is the cross-function
// half: main (bank $00) calls far_leaf, which the .far_text linker section places
// in bank $01 ($018xxx). The call is emitted as JSL ($22, pushes a 3-byte PBR:PC
// return) so the program bank follows into bank $01; far_leaf returns with RTL
// ($6B, pops the 3 bytes) back to bank $00. Both are driven by the function's
// section attribute, so caller (JSL) and callee (RTL) always agree.
//
// The argument passes in the normal calling convention (8-bit, in A) and the
// result returns in A, so this is a16-INDEPENDENT: the far-call MECHANISM doesn't
// care about accumulator width (unlike a far-pointer VALUE, which is 32-bit).
//
// far_leaf is a LEAF (no internal calls) and touches no far data: a far function
// that JSR'd a near function would keep the program bank at $01 and execute the
// wrong bank's bytes — the general mixed-banking case is a follow-up. The seed is
// laundered through a volatile so the call can't be constant-folded away.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 -Os far_call.c
// Built + booted in MAME and bsnes-jg by dev/far_call.sh (host: dev/run.sh far_call).
// See docs/plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md (Phase 1).

#include <stdint.h>

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders the argument so the call isn't folded to a constant.
volatile uint8_t seed;

// A LEAF function placed in bank $01. Called via JSL, returns via RTL. noinline so
// it is genuinely called (not inlined into main); pure compute, no calls, no far data.
__attribute__((section(".far_text"), noinline)) static uint8_t far_leaf(uint8_t x) {
  return (uint8_t)(x ^ 0x5A);
}

int main(void) {
  seed = 0xA9;
  corpus_result = far_leaf(seed); // JSL far_leaf (bank $01); RTL back; 0xA9 ^ 0x5A = 0xF3
  for (;;) __asm__ volatile("wai");
}
