// #321 native s16 — native 16-bit SIGNED ordering compares (`< <= > >=` on short).
//
// Signed order equals unsigned order after flipping the sign bit:
// a <s b  <=>  (a ^ 0x8000) <u (b ^ 0x8000). Under +mos-a16 each signed compare
// should select to `eor #$8000` on the operand(s) + the native 16-bit unsigned
// compare (rep; lda; cmp; sep; bcc/bcs) — NOT the 8-bit N^V byte chain.
//
// NEGATIVE operands make the test meaningful: an unsigned (broken) interpretation
// would treat -2 (0xFFFE) as a huge value and get every ordering wrong.
//
//   (-2) <  1   -> true   r |= 0x0001
//   (-2) >  1   -> false  (no bit)
//   (-5) <  (-2)-> true   r |= 0x0010   (both negative)
//    7   >= (-9)-> true   r |= 0x0100
//   corpus_result = 0x0111
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16scmp.c
// See docs/plans/2026-06-15-321-native-16bit-signed-compares.md.

volatile short n2 = -2;
volatile short p1 = 1;
volatile short n5 = -5;
volatile short p7 = 7;
volatile short n9 = -9;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short r = 0;
  if (n2 <  p1) r |= 0x0001;   // -2 < 1   -> true
  if (n2 >  p1) r |= 0x1000;   // -2 > 1   -> false (stays clear)
  if (n5 <  n2) r |= 0x0010;   // -5 < -2  -> true
  if (p7 >= n9) r |= 0x0100;   // 7 >= -9  -> true
  corpus_result = r;            // 0x0111
  for (;;) {
  }
}
