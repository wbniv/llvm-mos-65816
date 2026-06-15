// #321 native s16 — fold near-abs global operands into the 16-bit compare.
//
// Every compare here is GLOBAL-vs-GLOBAL, so both operands are near-abs 16-bit
// loads. With the compare-operand fold (selectSbc16 -> lda abs / cmp abs) each
// `if` should compile to `rep; lda abs; cmp abs; sep; bcc/bcs` — NO `lda abs;
// sta tmp` round-trip and NO `cmp zp` reading a materialized Imag16 pair. The
// lo<hi case (low byte bigger, high byte smaller) proves all 16 bits compare.
//
//   x  >  y   -> 0x4000 > 0x2000  -> true   r |= 0x0001
//   y  >  x   -> 0x2000 > 0x4000  -> false  (stays clear)
//   x  >= z   -> 0x4000 >= 0x4000 -> true   r |= 0x0300
//   y  <  x   -> 0x2000 < 0x4000  -> true   r |= 0x4000
//   lo <  hi  -> 0x00FF < 0x0100  -> true   r |= 0x0002  (high-byte-differs)
//   corpus_result = 0x4303
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16abscmp.c
// See docs/plans/2026-06-15-321-native-16bit-compare-abs-operand-fold.md.

volatile unsigned short x  = 0x4000;
volatile unsigned short y  = 0x2000;
volatile unsigned short z  = 0x4000;   // equal to x, for the >= case
volatile unsigned short lo = 0x00FF;   // low byte 0xFF, high byte 0x00
volatile unsigned short hi = 0x0100;   // high byte differs
volatile unsigned short corpus_result;

int main(void) {
  unsigned short r = 0;
  if (x  >  y)  r |= 0x0001;   // true
  if (y  >  x)  r |= 0x0020;   // false (stays clear)
  if (x  >= z)  r |= 0x0300;   // true
  if (y  <  x)  r |= 0x4000;   // true
  if (lo <  hi) r |= 0x0002;   // true (high-byte-differs)
  corpus_result = r;            // 0x0001 | 0x0300 | 0x4000 | 0x0002 = 0x4303
  for (;;) {
  }
}
