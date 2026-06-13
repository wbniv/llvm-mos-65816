// Corpus: control flow — for / while / do-while / if / switch. Catches branch and
// loop lowering. Loop bounds and the switch selector are volatile so the loops must
// actually run (no constant folding).
//
// Result (unsigned 16-bit):
//   for:   sum 1..100               = 5050
//   while: sum of evens 2..100      = 2550   (running 7600)
//   do:    sum 0..9                 =   45   (running 7645)
//   switch sel=3                    =   30   (running 7675)
//   total = 7675 = 0x1DFB
#include <stdint.h>

volatile uint16_t n   = 100;
volatile uint8_t  sel = 3;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t r = 0, i;

  for (i = 1; i <= n; i++) r += i;                 // 5050

  uint16_t w = n, ev = 0;
  while (w > 0) { if ((w & 1) == 0) ev += w; w--; } // 2550
  r += ev;

  uint16_t d = 0, k = 0;
  do { d += k; k++; } while (k < 10);               // 45
  r += d;

  uint16_t s;
  switch (sel) {
    case 1:  s = 10; break;
    case 2:  s = 20; break;
    case 3:  s = 30; break;
    default: s = 0;
  }
  r += s;                                           // 30

  corpus_result = r;
  for (;;) {}
}
