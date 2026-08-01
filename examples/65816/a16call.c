// #321 native s16 — cross-block REP/SEP mode-tracking: the M8-at-call invariant.
//
// A 16-bit-accumulator region with a function call in the middle. The 65816
// calling convention runs 8-bit at every call boundary (the callee assumes
// 8-bit A), so the pass MUST drop back to 8-bit (`sep #$20`) before the `jsl`
// and re-enter 16-bit (`rep #$20`) afterwards if more 16-bit work follows.
//
//   t = a16v + b16v;   // 16-bit add  -> 0x2345
//   t = ext(t);        // CALL: must execute in 8-bit mode
//   corpus_result = t + b16v;  // 16-bit add after the call -> 0x4456
//
// ext is noinline so it stays a real call. ext(0x2345) = 0x3345; then
// 0x3345 + 0x1111 = 0x4456. A call left in 16-bit mode would corrupt the stack /
// return and the result would not be 0x4456 on either emulator.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16call.c
// See docs/plans/2026-06-15-321-cross-block-repsep-mode-tracking.md.

volatile unsigned short a16v = 0x1234;
volatile unsigned short b16v = 0x1111;
volatile unsigned short corpus_result;

__attribute__((noinline)) unsigned short ext(unsigned short x) {
  return x + 0x1000;
}

int main(void) {
  unsigned short t = a16v + b16v;  // 0x2345 (16-bit add)
  t = ext(t);                      // 0x3345 (call — 8-bit at the boundary)
  corpus_result = t + b16v;        // 0x4456 (16-bit add after the call)
  for (;;) __asm__ volatile("wai");
}
