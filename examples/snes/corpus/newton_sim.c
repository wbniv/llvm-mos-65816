/* Corpus slice: Newton's-method fractal, HAL-free. Differential engine checks 5 ways:
 * host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/newton.h with the ROM (newton.c) and host oracle (tools/newton-sim.c).
 * State is stack-resident (gate runs 64 iterations; no large arrays needed here). */
#include "../../65816/newton.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = newton_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
