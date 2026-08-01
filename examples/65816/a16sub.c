// #321 Increment 1b (subtract): a 16-bit-accumulator SUB (a16 - b16) -> A16.
// Under +mos-a16 this compiles to sec; rep #$20; lda; sbc; sta; sep #$20.
volatile unsigned short a16v = 0x1234;
volatile unsigned short b16v = 0x1111;
volatile unsigned short g16;
volatile unsigned short corpus_result;
int main(void) {
  g16 = a16v - b16v;        // 0x1234 - 0x1111 = 0x0123
  corpus_result = g16;
  for (;;) __asm__ volatile("wai");
}
