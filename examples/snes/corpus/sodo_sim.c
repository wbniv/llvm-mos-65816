/* Corpus slice: sodo HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises signed 64-bit divide+modulo (__divdi3/__moddi3, sign-corrected) via a
   signed odometer ticking through zero, decomposed into decimal digits. */
#include "../../65816/sodo.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = sodo_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
