// #321 Increment 1b: a real 16-bit-accumulator ADD (a16 + b16) -> A16.
// Under +mos-a16 this should compile to rep #$20; lda a; clc; adc b; sta g; sep #$20.
volatile unsigned short a16v = 0x1234;
volatile unsigned short b16v = 0x1111;
volatile unsigned short g16;
volatile unsigned short corpus_result;
int main(void) {
  g16 = a16v + b16v;        // 0x1234 + 0x1111 = 0x2345
  corpus_result = g16;      // read back by the harness
  for (;;) {}
}
