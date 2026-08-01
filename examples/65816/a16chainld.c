// #321 native s16 load-fold (c): a MULTI-USE 16-bit add chain. `t = a + b + c + d`
// (four near-abs globals) whose result is reused (stored three times) threads the
// running sum through A16 in one go — `lda a; clc; adc b; clc; adc c; clc; adc d;
// sta t` — instead of round-tripping the partial sum through an Imag16 pair between
// every add (`...; adc b; sta tmp; lda tmp; clc; adc c; ...`). add_chain16 (Increment
// 1c) only fired store-rooted; add_chain16_ld handles the multi-use register result.
//
//   a=0x1000 b=0x0200 c=0x0030 d=0x0004  ->  t = 0x1234
//   g = t; h = t; corpus_result = t;     (multi-use -> add_chain16_ld)
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16chainld.c
// See docs/plans/2026-06-15-321-native-s16-add-chain-multiuse.md.

volatile unsigned short a = 0x1000;
volatile unsigned short b = 0x0200;
volatile unsigned short c = 0x0030;
volatile unsigned short d = 0x0004;
volatile unsigned short g, h;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short t = a + b + c + d;   // 4-term chain, result reused below
  g = t;
  h = t;
  corpus_result = t;                  // 0x1234
  for (;;) __asm__ volatile("wai");
}
