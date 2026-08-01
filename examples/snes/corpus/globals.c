// Corpus: initialized .data globals + zeroed .bss globals, read back at runtime. This
// directly exercises OUR crt0 init chain (the .data copy from LMA->VMA and the .bss
// clear). A regression in either shows up here. `one` is volatile so the .data reads
// can't be folded; a non-zero .bss adds a poison value that changes the result.
//
// Result (unsigned 16-bit):
//   sum data_vals = 0x1111+0x2222+0x3333+0x4444 = 43690 (0xAAAA)
//   + data_byte 0xAB (171)                              = 43861
//   .bss is zero (crt0 cleared it) -> no poison
//   total = 43861 = 0xAB55
#include <stdint.h>

uint16_t data_vals[4] = { 0x1111, 0x2222, 0x3333, 0x4444 };  // .data
uint8_t  data_byte    = 0xAB;                                // .data
uint16_t bss_vals[8];                                        // .bss (must be zeroed)
uint8_t  bss_byte;                                           // .bss
volatile uint8_t  one = 1;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t r = 0;
  uint8_t i;

  for (i = 0; i < 4; i++) r += (uint16_t)(data_vals[i] * one);  // 43690
  r += (uint16_t)(data_byte * one);                             // +171 = 43861

  uint16_t bsssum = 0;
  for (i = 0; i < 8; i++) bsssum += bss_vals[i];
  bsssum += bss_byte;
  if (bsssum != 0) r += 0xF000;   // poison: crt0 failed to clear .bss

  corpus_result = r;
  for (;;) __asm__ volatile("wai");
}
