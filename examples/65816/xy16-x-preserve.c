#include <stdint.h>

extern uint8_t stack_pop_byte(void);
extern uint8_t stack_push_byte(void);
extern uint8_t stack_pop_word(void);
extern uint8_t stack_push_word(void);
extern uint8_t stack_live_nz(void);

volatile uint16_t corpus_result;

/* The MIR functions use a full-width index into WRAM. Check their stack
   arguments, accumulator stores, condition flags, and byte return values. */
int main(void) {
  volatile uint8_t *const ram = (volatile uint8_t *)0x1000;
  uint16_t failures = 0;
  for (unsigned i = 0; i != 32; ++i) {
    ram[511] = 123;
    ram[512] = 0;
    if (stack_pop_byte() != 123 || ram[768] != 123) failures |= 1;
    if (stack_push_byte() != 123 || ram[769] != 123) failures |= 2;
    if (stack_pop_word() != 123 || ram[511] != 123 || ram[512] != 171)
      failures |= 4;
    if (stack_push_word() != 123 || ram[770] != 123 ||
        ram[771] != 123 || ram[772] != 171) failures |= 8;
    if (stack_live_nz() != 123 || ram[511] != 123 || ram[512] != 171)
      failures |= 16;
  }
  corpus_result = failures ? failures : 0xD77B;
  for (;;) __asm__ volatile("wai");
}
