/* Corpus slice: duff HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises Duff's device — irreducible loop-switch control flow (a switch whose case
   labels land in the middle of a do/while loop body). */
#include "../../65816/duff.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = duff_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
