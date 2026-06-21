// #320 follow-up (a) — FAR FUNCTION POINTERS: an INDIRECT call through a far
// (24-bit) code pointer. A function placed in bank $01 (.far_text) has its FULL
// 24-bit address taken as a far (addrspace 2) pointer value, then called via the
// stash-then-thunk mechanism (IR-rep #1): the 24-bit target is stored into the
// runtime slot __mos_far_target and a JSL to __call_indir_far long-indirect-jumps
// (`jml (__mos_far_target)`, $DC) to it; the far target's RTL returns to the
// original call site. The far address's bank byte is materialized by the backend's
// address-of-a-far-symbol path (`#mos24bank`, R_MOS_ADDR24_BANK).
//
// This is the e2e differential gate for sub-task (a) — it exercises Gap A (24-bit
// address-of, incl. the bank), the far-pointer p2 value decompose (Layer 3 / 0004),
// and the JSL'd thunk call together, on real silicon (MAME + bsnes-jg).
//
// Front-end note: clang forbids address-space-qualified *function* types and
// collapses a far-data alias that shares a defined AS0 function's name back to the
// near (bank-less) address. So the far call surface the eventual `far` attribute
// (F2) will provide is emulated here by hand: far_leaf is a real .far_text C
// function, and its 24-bit address is taken through a DISTINCT-named linker alias
// viewed as a far (addrspace 2) data symbol — no name collision, so &it is a true
// p2 and the bank survives. The call itself uses the runtime thunk directly.
//
// Needs +mos-a16: a far pointer is a 32-bit value and 32-bit value legalization is
// a16-gated (exactly as far_cast.c / far_indir.c). The gate is host-expected ==
// +mos-a16 on both emulators; there is NO default leg (the 8-bit build legitimately
// can't decompose a 32-bit far-pointer value).
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os far_fnptr.c
// Built + booted in MAME and bsnes-jg by dev/far_fnptr.sh (host: dev/run.sh far_fnptr).
// See docs/plans/2026-06-21-320-far-calls-followups.md (a).

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// The runtime far-target slot + the JSL'd indirect-long thunk
// (platforms/snes/call-indir-far.s). __call_indir_far(args) forwards its argument
// registers untouched to the far target and returns the target's value.
extern volatile uint32_t __mos_far_target;
extern uint8_t __call_indir_far(uint8_t);

// A FAR function placed in bank $01 (RTL-returning, by its .far_text section).
// far_leaf(x) = x ^ 0xA5.
__attribute__((section(".far_text"), noinline)) uint8_t far_leaf(uint8_t x) {
  return (uint8_t)(x ^ 0xA5);
}

// A distinct-named linker alias of far_leaf's address, declared as a far
// (addrspace 2) data symbol. Because the name differs from the AS0 function
// "far_leaf", clang does not collapse it — &far_leaf_ref is a genuine p2, so the
// backend materializes the full 24-bit address (bank included) via R_MOS_ADDR24.
__asm__(".globl __far_leaf_addr\n.set __far_leaf_addr, far_leaf\n");
extern FAR const uint8_t far_leaf_ref __asm__("__far_leaf_addr");

int main(void) {
  // 24-bit address of far_leaf (Gap A: #mos24segmentlo/hi + #mos24bank).
  __mos_far_target = (uint32_t)(FAR const void *)&far_leaf_ref; // "set far target"
  // Far-indirect call: far_leaf(0x5A) = 0x5A ^ 0xA5 = 0xFF, via JSL __call_indir_far.
  corpus_result = __call_indir_far(0x5A);
  for (;;) { // stay alive while MAME settles
  }
}
