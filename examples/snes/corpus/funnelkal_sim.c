/* Corpus slice: funnelkal HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_FSHL/G_FSHR two-source funnel shift via __builtin_elementwise_fshl/fshr
   with A!=B so matchFunnelShiftToRotate cannot fold to G_ROTL/G_ROTR. */
#include "../../65816/funnelkal.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = funnelkal_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
