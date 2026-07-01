/* Corpus slice: satcomet HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_UADDSAT/G_USUBSAT (uint8 glow/decay) AND G_SADDSAT/G_SSUBSAT
   (int16 velocity kicks) via __builtin_elementwise_add_sat/sub_sat.
   All four -> lowerAddSubSatToMinMax at MOSLegalizerInfo.cpp:246. */
#include "../../65816/satcomet.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = satcomet_gate_crc();
    for (;;) {}
    return 0;
}
