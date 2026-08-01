// #321 native s16 — native 16-bit absolute load/store (`g = gg`).
//
// Under +mos-a16 a 16-bit global-to-global copy should be ONE native 16-bit
// absolute load + store under one rep/sep — `rep #$20; lda gg; sta g; sep #$20` —
// instead of the 4-op 8-bit X/Y byte shuffle (ldx gg; ldy gg+1; stx g; sty g+1)
// with no rep/sep.
//
//   g = gg;               // native 16-bit absolute load + store (0x5A3C)
//   corpus_result = g + 1; // 0x5A3D  (proves the full 16 bits copied)
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16abs.c
// See docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md.

volatile unsigned short gg = 0x5A3C;
volatile unsigned short g;
volatile unsigned short corpus_result;

int main(void) {
  g = gg;                 // 16-bit absolute load + store
  corpus_result = g + 1;  // 0x5A3D
  for (;;) __asm__ volatile("wai");
}
