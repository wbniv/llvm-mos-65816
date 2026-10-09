// Corpus: integer ALU across widths (uint8/16/32 add/sub/mul/div/mod/shift/bitwise).
// Catches multi-byte arithmetic + mul/div libcall codegen — exactly what M2's 16-bit
// register mode rewrites. Inputs are volatile so -Os can't fold the program to a constant.
//
// Result (unsigned 16-bit; note llvm-mos `int` is 16-bit so uint16_t promotes to unsigned):
//   a8+b8 255 | a8&b8 0 | a8|b8 255 | a8^b8 255 | a16*b16 7000 | a16/b16 142 | a16%b16 6
//   | a32/b32 33333 | a32%b32 1 | a16<<1 2000 | a16>>2 250
//   sum = 255+0+255+255+7000+142+6+33333+1+2000+250 = 43497 = 0xA9E9
#include <stdint.h>

volatile uint8_t  a8  = 0xF0, b8 = 0x0F;
volatile uint16_t a16 = 1000,  b16 = 7;
volatile uint32_t a32 = 100000, b32 = 3;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t r = 0;
  r += (uint16_t)(a8 + b8);
  r += (uint16_t)(a8 & b8);
  r += (uint16_t)(a8 | b8);
  r += (uint16_t)(a8 ^ b8);
  r += (uint16_t)(a16 * b16);
  r += a16 / b16;
  r += a16 % b16;
  r += (uint16_t)(a32 / b32);
  r += (uint16_t)(a32 % b32);
  r += (uint16_t)(a16 << 1);
  r += (uint16_t)(a16 >> 2);
  corpus_result = r;
  for (;;) __asm__ volatile("wai");
}
