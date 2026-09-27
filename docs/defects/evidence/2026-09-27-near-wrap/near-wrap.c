#include <stdint.h>
#define FAR __attribute__((address_space(2)))
volatile uint16_t corpus_result;
__attribute__((noinline,used))
uint8_t near_wrap(const uint8_t *p, int16_t offset) {
  return p[offset];
}
asm(".text\n.global wrap_bank7e\nwrap_bank7e:\n"
    "php\n.byte $8b\n.byte $f4,$7e,$7e\n.byte $ab,$ab\n"
    "jsr near_wrap\n.byte $ab\nplp\nrts\n");
uint8_t wrap_bank7e(const uint8_t *p, int16_t offset);
int main(void) {
  *(volatile FAR uint8_t *)0x7ea802 = 0x5a;
  *(volatile FAR uint8_t *)0x7fa802 = 0xc3;
  uint8_t value = wrap_bank7e((const uint8_t *)0xa806, -4);
  corpus_result = value == 0x5a ? 0x5cf0 : (uint16_t)(0xa500 | value);
  for (;;) __asm__ volatile("wai");
}
