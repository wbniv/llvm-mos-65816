// #321 Increment 1b (bitwise): 16-bit-accumulator AND/OR/XOR (a16 OP b16) -> A16.
// Under +mos-a16 each compiles to rep #$20; lda; and|ora|eor; sta; sep #$20 (no carry).
volatile unsigned short a16v = 0xFF0F;
volatile unsigned short b16v = 0x0FF0;
volatile unsigned short g_and, g_or, g_xor;
volatile unsigned short corpus_result;
int main(void) {
  g_and = a16v & b16v;       // 0xFF0F & 0x0FF0 = 0x0F00
  g_or  = a16v | b16v;       // 0xFF0F | 0x0FF0 = 0xFFFF
  g_xor = a16v ^ b16v;       // 0xFF0F ^ 0x0FF0 = 0xF0FF
  corpus_result = g_and;     // read back the AND result
  for (;;) __asm__ volatile("wai");
}
