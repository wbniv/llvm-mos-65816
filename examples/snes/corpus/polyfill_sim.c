/* Corpus slice: polyfill HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises a runtime-sized C99 VLA (int16_t xs[nv]) in pf_poly_area. */
#include "../../65816/polyfill.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = polyfill_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
