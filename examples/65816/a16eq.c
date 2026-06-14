// #321 native s16 — native 16-bit equality compares (`==` / `!=`).
//
// Under +mos-a16 each 16-bit `==`/`!=` feeding a branch should compile to one
// rep; lda; cmp; sep; beq/bne (a fused 16-bit compare-branch) instead of the old
// two-block 8-bit cmp/cpx chain. `a` and `c` differ in BOTH bytes, so a broken
// single-byte compare would misfire; the correct result proves all 16 bits compare.
//
//   a == b   (0x1234 == 0x1234) -> true   -> r |= 0x0001
//   a != c   (0x1234 != 0x00FF) -> true   -> r |= 0x0010
//   a == c   (0x1234 == 0x00FF) -> false  -> (no bit)
//   corpus_result = 0x0011
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16eq.c
// See docs/plans/2026-06-15-321-native-16bit-equality-compares.md.

volatile unsigned short a = 0x1234;
volatile unsigned short b = 0x1234;
volatile unsigned short c = 0x00FF;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short r = 0;
  if (a == b) r |= 0x0001;   // equal -> true
  if (a != c) r |= 0x0010;   // differ -> true
  if (a == c) r |= 0x0100;   // differ -> false (stays clear)
  corpus_result = r;          // 0x0011
  for (;;) {
  }
}
