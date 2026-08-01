// #321 native s16 — loop strength-reduction to a native 16-bit add. A counted
// increment loop `while (i) { x = x + 1; i = i - 1; }` should be COMBINED by the
// optimizer into a single `x += n` (the trip count), computed as one native 16-bit
// add under +mos-a16 — not an executed per-iteration inc loop, not an 8-bit byte
// chain, not a libcall. This guards that the strength-reduction combine stays
// semantically correct after the native-s16 add/sub + inc/dec legalization changes.
//
//   x = seed = 0x1234; loop adds 1 a total of n = 5 times -> x = 0x1239.
//   corpus_result = 0x1239 on BOTH MAME and bsnes-jg.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16loopred.c
// See docs/plans/2026-06-15-321-native-s16-inc-dec-accumulator.md.

volatile unsigned short seed = 0x1234;
volatile unsigned short n = 5;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short x = seed;
  unsigned short i = n;
  while (i) {            // counted loop -> strength-reduced to x += n
    x = x + 1;
    i = i - 1;
  }
  corpus_result = x;     // 0x1234 + 5 = 0x1239
  for (;;) __asm__ volatile("wai");
}
