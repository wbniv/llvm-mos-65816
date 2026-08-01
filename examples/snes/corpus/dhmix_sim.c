/* Corpus slice: dhmix HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises 64-bit modular exponentiation (__muldi3 + __umoddi3 hot loop) via Diffie-Hellman. */
#include "../../65816/dhmix.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = dhmix_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
