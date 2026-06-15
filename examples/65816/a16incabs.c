// #321 native s16 inc/dec on globals (`g = g ± 1`): selects to `lda <g>; inc/dec a;
// sta <g>` — dropping the `clc` and shrinking `adc #$0001` to a 1-byte `inc a`/`dec a`
// — using the same 24-bit long addressing the compiler already uses for data. A
// DBR-relative `inc abs` memory-RMW is deliberately NOT used (no `inc long` on the
// 65816; it would couple correctness to DBR==0 + bank-0 LoRAM placement). See
// docs/plans/2026-06-15-321-native-s16-inc-dec-memory-rmw.md.
//
//   g1 = g1 + 1 (x2) -> 0x1002   inc a   (same-global; volatile keeps both)
//   g2 = g2 - 1       -> 0x1FFF   dec a   (same-global)
//   o  = a  + 1       -> 0x0501   inc a   (cross-global)
//   corpus_result = g1 + g2 + o = 0x3502
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16incabs.c

volatile unsigned short g1 = 0x1000;
volatile unsigned short g2 = 0x2000;
volatile unsigned short a = 0x0500;
volatile unsigned short o;
volatile unsigned short corpus_result;

int main(void) {
  g1 = g1 + 1;   // inc a
  g1 = g1 + 1;   // inc a
  g2 = g2 - 1;   // dec a
  o = a + 1;     // inc a (cross-global)
  corpus_result = g1 + g2 + o;   // 0x1002 + 0x1FFF + 0x0501 = 0x3502
  for (;;) {
  }
}
