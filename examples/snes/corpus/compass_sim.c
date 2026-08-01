/* Corpus slice: compass HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_FCOPYSIGN via __builtin_copysignf(1.0f, (float)(dx+phase))
   and G_IS_FPCLASS via __builtin_signbitf. Both are inline sign-bit operations.
   First demo to use __builtin_copysignf. */
#include "../../65816/compass.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = compass_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
