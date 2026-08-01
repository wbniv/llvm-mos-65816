// Corpus: arrays + a const lookup table in .rodata + a RAM array. Catches addressing
// modes and section placement — what M1's far/absolute addressing changes. The volatile
// index forces a runtime indexed load from the .rodata table (can't be folded away).
//
// Result (unsigned 16-bit):
//   sum lut[0..7] = 3+1+4+1+5+9+2+6        = 31
//   lut[idx]*100, idx=5 -> 9*100           = 900   (running 931)
//   ram[i]=lut[i]*2; sum ram = 2*31        = 62    (running 993)
//   total = 993 = 0x03E1
#include <stdint.h>

static const uint8_t lut[8] = { 3, 1, 4, 1, 5, 9, 2, 6 };
volatile uint8_t  idx = 5;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t r = 0;
  uint8_t i;

  for (i = 0; i < 8; i++) r += lut[i];          // 31
  r += (uint16_t)(lut[idx] * 100);              // 900

  uint8_t ram[8];
  for (i = 0; i < 8; i++) ram[i] = (uint8_t)(lut[i] * 2);
  for (i = 0; i < 8; i++) r += ram[i];          // 62

  corpus_result = r;
  for (;;) __asm__ volatile("wai");
}
