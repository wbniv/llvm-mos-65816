/* Corpus slice: divclock HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises constant-divisor strength reduction (magic reciprocal, not __udivsi3). */
#include "../../65816/divclock.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = divclock_gate_crc();
    for (;;) {}
    return 0;
}
