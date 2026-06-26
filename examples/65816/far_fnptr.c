// #320 follow-up (a) — FAR FUNCTION POINTERS: an INDIRECT call through a far
// (24-bit) code pointer, expressed in plain single-file C via the MOS `far`
// (== `long_call`) function attribute — no asm, no `.set`, no hand-rolled
// __mos_far_target plumbing. clang's F2 front-end lowers a call to a `far`
// function into the proven far-indirect ("stash-then-thunk") sequence: it
// materializes the function's FULL 24-bit address (#mos24segmentlo/hi +
// #mos24bank, R_MOS_ADDR24) into the runtime slot __mos_far_target and JSLs the
// bank-0 trampoline __call_indir_far, which `jml (__mos_far_target)`s ($DC)
// across the bank; the far target's RTL returns to the original call site.
//
// This is the e2e differential gate for sub-task (a): it exercises Gap A (24-bit
// address-of incl. the bank), the far-pointer p2 value decompose (Layer 3 /
// 0004), the JSL'd thunk call, AND the clang `far` attribute / call-rewrite
// (F2), all together on real silicon (MAME + bsnes-jg).
//
// Two properties make far_leaf a valid far-call target:
//   * section(".far_text")  -> placed in bank $01, so it RETURNS VIA RTL (pops
//                              the 3-byte PBR:PC pushed by the JSL trampoline).
//   * far (== long_call)     -> every call to it goes through the 24-bit
//                              far-indirect sequence above (the F2 rewrite).
// Both are required: far functions return RTL (placement) and are called far
// (attribute). The `far` attribute is opt-in — a plain .far_text function called
// directly still uses the existing direct-JSL far call; `far` is for the
// function-pointer / indirect dispatch case proven here.
//
// Needs +mos-a16: a far pointer is a 32-bit value and 32-bit value legalization
// is a16-gated (exactly as far_cast.c / far_indir.c). The gate is host-expected
// == +mos-a16 on both emulators; there is NO default leg (the 8-bit build
// legitimately can't decompose a 32-bit far-pointer value).
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os far_fnptr.c
// Built + booted in MAME and bsnes-jg by dev/far_fnptr.sh (host: dev/run.sh far_fnptr).
// See docs/plans/2026-06-26-320-thunk-tail-calls.md (the Phase B landing) and
// docs/plans/2026-06-21-320-far-calls-followups.md (a).

#include <stdint.h>

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// A FAR function placed in bank $01 (.far_text => RTL-returning). The `far`
// attribute makes every call to it use the 24-bit far-indirect call sequence.
// far_leaf(x) = x ^ 0xA5.
__attribute__((section(".far_text"), noinline, far))
uint8_t far_leaf(uint8_t x) {
  return (uint8_t)(x ^ 0xA5);
}

int main(void) {
  // A single-file far function-pointer call: clang stashes far_leaf's full
  // 24-bit address into __mos_far_target and dispatches through __call_indir_far.
  // far_leaf(0x5A) = 0x5A ^ 0xA5 = 0xFF (the value crossed the bank).
  corpus_result = far_leaf(0x5A);
  for (;;) { // stay alive while MAME settles
  }
}
