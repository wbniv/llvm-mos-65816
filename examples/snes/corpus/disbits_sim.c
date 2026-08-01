/* Corpus slice: disbits HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises bitfields that straddle byte boundaries inside a uint32_t (multi-byte shift+mask). */
#include "../../65816/disbits.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = disbits_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
