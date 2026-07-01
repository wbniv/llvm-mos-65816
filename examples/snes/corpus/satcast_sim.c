/* Corpus slice: satcast HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises fminf → G_FMINNUM + fmaxf → G_FMAXNUM + (int16_t) → G_FPTOSI
   (legalizer :502 inserts NaN guard); SDK fminf/fmaxf (math.cc:18-19).
   First demo to use any fminf/fmaxf operation. */
#include "../../65816/satcast.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = satcast_gate_crc();
    for (;;) {}
    return 0;
}
