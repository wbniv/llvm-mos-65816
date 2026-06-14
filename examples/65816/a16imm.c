// #321 Increment 1b (immediate): 16-bit-accumulator ALU with a constant operand.
// g = a OP #imm16 -> lda a; OP #imm; sta g. Subtract-by-constant folds to add of
// the negated constant (no SBC immediate needed).
volatile unsigned short a16v = 0x1200;
volatile unsigned short g_add, g_sub, g_and;
volatile unsigned short corpus_result;
int main(void) {
  g_add = a16v + 0x0345;     // 0x1200 + 0x0345 = 0x1545
  g_sub = a16v - 0x0100;     // 0x1100 (folds to add #$FF00)
  g_and = a16v & 0x0FF0;     // 0x1200 & 0x0FF0 = 0x0200
  corpus_result = g_add;     // read back the add result
  for (;;) {}
}
