// #320 Phase B — FAR-INDIRECT TAIL CALL: a far function whose TAIL is an indirect
// call through a far code pointer, folded to a single long jump. This is the
// far-indirect analogue of far_tail.c (direct far->far) and far_near_call.c
// (far->near thunk tail).
//
// Shape:
//   main (near)  --JSL far_outer-->          far_outer (bank $01, .far_text)
//   far_outer    --return far_leaf(x)-->      a far-INDIRECT tail (far_leaf is `far`):
//                                             stash far_leaf's 24-bit addr in
//                                             __mos_far_target, then `JSL __call_indir_far`,
//                                             and since far_outer is .far_text it returns RTL
//                                             => the block tail is `JSL __call_indir_far; RTL`.
//
// MOSLateOptimization::tailJMP's IndirFarThunk arm folds that tail to a single
// `TailJML __call_indir_far` ($5C long jump): the thunk `jml (__mos_far_target)`s to
// far_leaf, whose RTL pops main's 3-byte return — control returns straight to main
// (tail-call style), −1 B and the redundant return push/pop dropped. far_leaf keeps
// its own RTL. Needs the __call_indir_far runtime stub (platforms/snes/call-indir-far.s)
// AND +mos-a16 (a far pointer is a 32-bit value).
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os far_indir_tail.c
// Built + booted in MAME and bsnes-jg by dev/far_indir_tail.sh (host: dev/run.sh far_indir_tail).
// See docs/plans/2026-06-26-320-thunk-tail-calls.md (Phase B).

#include <stdint.h>

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// A FAR function placed in bank $01 (.far_text => RTL-returning), AND `far` so every
// call to it uses the 24-bit far-INDIRECT sequence (JSL __call_indir_far). far_leaf(x) = x ^ 0xA5.
__attribute__((section(".far_text"), noinline, far))
uint8_t far_leaf(uint8_t x) {
  return (uint8_t)(x ^ 0xA5);
}

// A FAR function (bank $01, .far_text => RTL-returning) that is NOT itself `far`, so
// main reaches it via a plain direct far call (JSL far_outer). Its tail
// `return far_leaf(x)` is a far-indirect call (far_leaf is `far`), so the block tail is
// `JSL __call_indir_far; RTL` — the IndirFarThunk fold turns it into a long jmp.
__attribute__((section(".far_text"), noinline))
uint8_t far_outer(uint8_t x) {
  return far_leaf(x);
}

int main(void) {
  // far_outer(0x5A) -> far_leaf(0x5A) = 0x5A ^ 0xA5 = 0xFF (returned straight to main
  // by far_leaf's RTL, past the folded far_outer tail).
  corpus_result = far_outer(0x5A);
  for (;;) __asm__ volatile("wai");
}
