/* Corpus slice: cgrade HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises a 10-argument function call forcing >register-count argument spilling onto the soft stack. */
#include "../../65816/cgrade.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = cgrade_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
