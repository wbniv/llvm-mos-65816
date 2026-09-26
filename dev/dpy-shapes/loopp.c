#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t tab[];
volatile uint16_t base;
uint8_t dst[64];
// #321 Phase 2 inc 2 customers under +mos-a16 (loop.c's `tab[o + j]` has a 16-bit offset, which
// only a 16-bit Y (+mos-xy16) can hold). Pointer form of the same blit: the far source pointer is
// formed once and the loop index is 8-bit, so the offset is provably 0..255.
void blitp(void){
  const FAR uint8_t *src = tab + base;
  for (uint8_t j = 0; j < 64; j++) dst[j] = src[j];
}
// A global far base is excluded from the runtime-pointer fold.
void blitg(void){
  for (uint8_t j = 0; j < 64; j++) dst[j] = tab[j];
}
