/* Corpus slice: nrecip HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises a multiply-only Newton-Raphson fixed-point reciprocal (iterative refinement, no divide). */
#include "../../65816/nrecip.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = nrecip_gate_crc();
    for (;;) {}
    return 0;
}
