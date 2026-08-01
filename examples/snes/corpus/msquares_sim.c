/* Corpus slice: msquares HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. */
#include "../../65816/msquares.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = msquares_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
