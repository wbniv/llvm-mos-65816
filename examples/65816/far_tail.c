// #320 far TAIL calls — a FAR function (bank $01) tail-calls ANOTHER far function.
//
// far->far calls already work: a `return far_x(...)` in a .far_text function lowers
// to `JSL far_x` and the caller (being .far_text) returns via `RTL`. But the post-RA
// tail-call peephole (MOSLateOptimization::tailJMP) only recognized the NEAR shape
// `JSR g; RTS` -> `TailJMP g`, so the far tail `JSL far_x; RTL` was left intact (a
// redundant 3-byte return push + RTL pop). This test proves the far arm of that
// peephole folds `JSL far_x; RTL` into a single direct long jump `TailJML` (opcode
// $5C, JMP_AbsoluteLong, sets PBR:PC, relocates R_MOS_ADDR24): far_x then runs and
// its OWN RTL pops the ORIGINAL caller's 3-byte JSL return, returning past the
// intervening far function — tail-call semantics, -1 byte + no redundant push/pop.
//
// Two complementary shapes, both .far_text (bank $01):
//   * far_outer  — the MINIMAL single far->far tail (`return far_addk(x)`). This is
//     the size/disasm demonstrator: it folds 5 B (jsl+rtl) -> 4 B (one $5C jmp).
//   * far_pick   — a CONDITIONAL with TWO far-tail blocks, tail-calling two leaves
//     that return DISTINCT values. This makes EXECUTION target-sensitive: the two
//     tail blocks are adjacent by construction (block A falls into block B), so a
//     broken block-A tail jump would fall through to block B and yield far_xork's
//     value instead of far_addk's — a wrong corpus_result, not a silent pass. (The
//     leaves share bank $01, so a plain adjacency/fall-through is the realistic
//     mis-lowering this catches; the disasm gate separately proves the $5C form.)
//
// a16-INDEPENDENT (8-bit values, A/X CC; the peephole is a pure post-RA opcode swap
// keyed on the RTL terminator + the callee's .far_ section, with no accumulator-mode
// reference) — dev/far_tail.sh exercises BOTH the default 8-bit and the +mos-a16
// build. The differential is host == mosw65816@MAME == mosw65816@bsnes-jg.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 -Os far_tail.c
// Built + booted in MAME and bsnes-jg by dev/far_tail.sh (host: dev/run.sh far_tail).
// See docs/plans/2026-06-22-320-far-tail-calls.md.

#include <stdint.h>

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders inputs so the chain isn't folded to a constant.
volatile uint8_t seed;
volatile uint8_t sel;

// Two FAR (bank $01) leaves with DISTINCT operations, so a mis-targeted tail jump
// produces a different value. noinline so the far call/return survive to the ROM.
__attribute__((section(".far_text"), noinline)) static uint8_t far_addk(uint8_t x) {
  return (uint8_t)(x + 0x11);
}
__attribute__((section(".far_text"), noinline)) static uint8_t far_xork(uint8_t x) {
  return (uint8_t)(x ^ 0x5A);
}

// MINIMAL far->far tail: body is a single tail call -> `JSL far_addk; RTL` ->
// folds to `TailJML far_addk` ($5C). The -1 B size demonstrator + disasm subject.
__attribute__((section(".far_text"), noinline)) static uint8_t far_outer(uint8_t x) {
  return far_addk(x); // far->far tail call
}

// CONDITIONAL far tail with TWO far-tail blocks. Each `return far_*(x)` is a far tail
// call -> two `JSL; RTL` -> two TailJML conversions. Execution discriminator: taking
// path A (sel != 0) must reach far_addk; if block A's $5C were mis-lowered to a
// fall-through it would drop into block B (far_xork) and return a DIFFERENT value.
__attribute__((section(".far_text"), noinline)) static uint8_t far_pick(uint8_t s, uint8_t x) {
  if (s)
    return far_addk(x); // far tail (block A)
  return far_xork(x);   // far tail (block B)
}

int main(void) {
  seed = 0xA9;
  sel = 0x01; // select path A (far_addk) in far_pick
  // far_outer(0xA9) = 0xA9 + 0x11      = 0xBA
  // far_pick(1,0xBA) = far_addk(0xBA)  = 0xBA + 0x11 = 0xCB   (correct, path A)
  //   a broken block-A tail jump would fall through to far_xork(0xBA)=0xBA^0x5A=0xE0.
  corpus_result = far_pick(sel, far_outer(seed));
  for (;;) { // stay alive while MAME settles
  }
}
