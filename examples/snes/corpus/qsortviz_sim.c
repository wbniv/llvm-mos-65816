/* Corpus slice: qsortviz HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises libc qsort with a function-pointer comparator (indirect call per compare). */
#include "../../65816/qsortviz.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = qsortviz_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
