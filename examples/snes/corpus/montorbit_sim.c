/* Corpus slice: montorbit HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises Montgomery REDC modular multiplication (__mulsi3 + G_LSHR + G_AND +
   __mulhi3 + conditional subtract) with NO __udivsi3/__umodsi3 — the division-free
   modmul member of the battery (distinct from #61 dhmix / #20 factorial). */
#include "../../65816/montorbit.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = montorbit_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
