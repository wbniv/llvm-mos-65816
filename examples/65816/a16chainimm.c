// #321 native s16 ALU-chain extension: a constant TERM inside a 16-bit add chain.
// `a + b + c + K` (>=2 near-abs global loads + a folded constant) now threads the
// running sum through A16 with the constant as a final `adc #imm` — `lda a; clc; adc b;
// clc; adc c; clc; adc #K; sta` — instead of falling off the chain at the constant and
// round-tripping each partial sum through an Imag16 pair. Covers both the store-rooted
// form (add_chain16) and the multi-use-result form (add_chain16_ld).
//
//   a=0x1000 b=0x0200 c=0x0030  ->  a+b+c = 0x1230
//   os = a + b + c + 0x0004           = 0x1234   (store-rooted chain + imm)
//   t  = a + b + c + 0x0105 (reused)  = 0x1335   (multi-use chain + imm)
//   corpus_result = os + t            = 0x2569
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16chainimm.c
// See docs/plans/2026-06-15-321-native-s16-add-chain-immediate.md.

volatile unsigned short a = 0x1000;
volatile unsigned short b = 0x0200;
volatile unsigned short c = 0x0030;
volatile unsigned short g, h, os;
volatile unsigned short corpus_result;

int main(void) {
  os = a + b + c + 0x0004;            // store-rooted chain + imm
  unsigned short t = a + b + c + 0x0105;  // multi-use chain + imm
  g = t;
  h = t;
  corpus_result = os + t;            // 0x1234 + 0x1335 = 0x2569
  for (;;) __asm__ volatile("wai");
}
