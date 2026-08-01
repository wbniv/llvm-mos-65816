/* Corpus slice: critters HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises resumable protothread functions (saved case-index re-entry, mid-loop case labels). */
#include "../../65816/critters.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = critters_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
