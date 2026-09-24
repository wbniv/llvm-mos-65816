#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t tab[];
volatile uint16_t base;
uint8_t dst[64];
// Realistic SNES idiom: copy a 64-byte run out of a far ROM table into WRAM,
// at a runtime 16-bit offset. 16-bit-ambient (+mos-a16).
void blit(void){
  uint16_t o = base;
  for (uint8_t j = 0; j < 64; j++) dst[j] = tab[o + j];
}
