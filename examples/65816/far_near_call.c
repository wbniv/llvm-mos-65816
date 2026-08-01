// #320 follow-up (b) — MIXED-BANKING: a FAR function (bank $01) calls a NEAR
// function (bank $00). Inc 4 Ph1 shipped far CALLS but a far function had to be a
// leaf (or call only other far functions): a near JSR out of bank $01 keeps the
// program bank at $01 and executes the wrong bank's bytes. This lifts that — a
// far->near call is routed through the bank-0 thunk __call_near_from_far via JSL
// (it pushes a near RTS return, near-indirect-jumps to the callee at PBR=$00, and
// RTLs back to the far caller), so the near callee runs in its own bank and its
// OWN near JSR/RTS work too.
//
// Call chain exercised:
//   main (bank $00) --JSL--> far_caller (bank $01)          [Inc 4 Ph1 far call]
//   far_caller      --JSL--> __call_near_from_far (bank $00) [follow-up (b) thunk]
//                    --jmp(ind)--> near_helper (bank $00)
//   near_helper     --JSR--> near_inner (bank $00)           [near call at PBR=$00]
// so it proves the program bank is $00 across the near callee's OWN near call, not
// just at entry. Returns rfold up the chain via RTS/RTS/RTL/RTL.
//
// a16-INDEPENDENT (8-bit values, A/X CC) — runs in the default 8-bit build too.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 -Os far_near_call.c
// Built + booted in MAME and bsnes-jg by dev/far_near_call.sh (host: dev/run.sh far_near_call).
// See docs/plans/2026-06-21-320-far-calls-followups.md (b).

#include <stdint.h>

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders the argument so the chain isn't folded to a constant.
volatile uint8_t seed;

// A NEAR (bank $00) leaf. noinline so the near JSR/RTS survive.
__attribute__((noinline)) static uint8_t near_inner(uint8_t x) {
  return (uint8_t)(x + 0x11);
}

// A NEAR (bank $00) helper that ITSELF makes a near call — so we prove PBR=$00 is
// held across the near callee's own JSR/RTS, not merely at the far->near entry.
__attribute__((noinline)) static uint8_t near_helper(uint8_t x) {
  return (uint8_t)(near_inner(x) ^ 0x5A); // near->near JSR inside the near helper
}

// A FAR function placed in bank $01. It calls a NEAR function — the mixed-banking
// case the follow-up enables (routes through __call_near_from_far via JSL).
__attribute__((section(".far_text"), noinline)) static uint8_t far_caller(uint8_t x) {
  return near_helper(x); // far->near call
}

int main(void) {
  seed = 0xA9;
  // 0xA9 + 0x11 = 0xBA; 0xBA ^ 0x5A = 0xE0.
  corpus_result = far_caller(seed);
  for (;;) __asm__ volatile("wai");
}
