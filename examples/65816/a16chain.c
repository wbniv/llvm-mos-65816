// #321 Increment 1c: a chained 16-bit ADD (a + b + c) -> the running sum stays in A16.
// Under +mos-a16: rep #$20; lda; clc; adc; clc; adc; sta; sep #$20 (one bracket).
volatile unsigned short a16v = 0x1000;
volatile unsigned short b16v = 0x0200;
volatile unsigned short c16v = 0x0030;
volatile unsigned short g16;
volatile unsigned short corpus_result;
int main(void) {
  g16 = a16v + b16v + c16v;   // 0x1000 + 0x0200 + 0x0030 = 0x1230
  corpus_result = g16;
  for (;;) __asm__ volatile("wai");
}
