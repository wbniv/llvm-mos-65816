/* Corpus slice: #10 Fourier epicycles, HAL-free. The differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises a sin/cos-LUT loop with 4 16x16->32 multiplies per harmonic + 32-bit accumulation
   under +mos-a16 (the many-multiply profile). See examples/65816/epicycles.h. */
#include "../../65816/epicycles.h"
volatile uint16_t corpus_result;
int main(void) {
    corpus_result = epi_gate_crc();
    for (;;) {}
    return 0;
}
