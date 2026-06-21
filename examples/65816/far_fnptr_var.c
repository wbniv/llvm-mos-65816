// #320 follow-up (a) — FAR FUNCTION POINTERS, the typed-VARIABLE surface: store a
// far (24-bit) code pointer in a variable and call THROUGH it, in plain
// single-file C. The `far` (== `long_call`) attribute rides a function-pointer
// TYPEDEF, so a variable of that type is a 32-bit far pointer (lowered to
// `ptr addrspace(2)`) that holds the full 24-bit address, and a call through it
// is lowered to the proven far-indirect ("stash-then-thunk") sequence:
//
//   far_fn_t fp = far_leaf;     // ptr addrspace(2) = &far_leaf's 24-bit address
//   corpus_result = fp(0x5A);   // store fp into __mos_far_target; JSL __call_indir_far
//
// This complements far_fnptr.c (the DIRECT `far_leaf(0x5A)` surface): here the
// far-ness rides the POINTER TYPE and the call is genuinely indirect through a
// runtime pointer value (clang ptrtoints the loaded fp into the slot). Both
// surfaces reach the same backend mechanism: __call_indir_far `jml
// (__mos_far_target)`s ($DC) across the bank and far_leaf's RTL returns to the
// original call site.
//
// far_leaf is `far` (so its type carries the far bit and matches far_fn_t — a
// non-far function would be an incompatible-pointer assignment) AND
// `section(".far_text")` (so it is placed in bank $01 and RETURNS VIA RTL,
// matching the 3-byte push the JSL trampoline makes).
//
// Needs +mos-a16: a far pointer is a 32-bit value (a16-gated 32-bit value
// legalization, as in far_cast/far_indir/far_fnptr). The gate is host-expected
// == +mos-a16 on both emulators; there is no default leg.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os far_fnptr_var.c
// Built + booted in MAME and bsnes-jg by dev/far_fnptr_var.sh (host: dev/run.sh far_fnptr_var).
// See docs/plans/2026-06-21-320-far-fnptr-typed-variable.md.

#include <stdint.h>

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// A FAR function-pointer type: the `far` attribute rides the typedef, so a
// variable of this type is a 32-bit far pointer and calls through it use the
// 24-bit far-indirect sequence.
typedef uint8_t (*far_fn_t)(uint8_t) __attribute__((far));

// A FAR function placed in bank $01 (.far_text => RTL-returning), itself `far`
// so its type matches far_fn_t. far_leaf(x) = x ^ 0xA5.
__attribute__((section(".far_text"), noinline, far))
uint8_t far_leaf(uint8_t x) {
  return (uint8_t)(x ^ 0xA5);
}

int main(void) {
  // Capture far_leaf's full 24-bit address into a far function-pointer variable,
  // then call through it. far_leaf(0x5A) = 0x5A ^ 0xA5 = 0xFF.
  far_fn_t fp = far_leaf;
  corpus_result = fp(0x5A);
  for (;;) { // stay alive while MAME settles
  }
}
