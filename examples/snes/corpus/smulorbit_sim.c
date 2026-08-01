/* Corpus slice: smulorbit HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_SMULO at s16 (lowerMulo) and s32 (__mulosi4) via
   __builtin_mul_overflow on int16_t and int32_t operands. */
#include "../../65816/smulorbit.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = smulorbit_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
