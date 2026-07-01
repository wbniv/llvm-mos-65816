/* Corpus slice: fabsridge HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_FABS via __builtin_fabsf in the tent-map iteration, targeting the
   TARGET-CUSTOM legalizeFAbs path at MOSLegalizerInfo.cpp:369 (inline sign-bit AND). */
#include "../../65816/fabsridge.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = fabsridge_gate_crc();
    for (;;) {}
    return 0;
}
