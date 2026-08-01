/* Corpus slice: gouraud HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. */
#include "../../65816/gouraud.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = gouraud_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
