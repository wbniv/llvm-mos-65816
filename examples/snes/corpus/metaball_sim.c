/* Corpus slice: metaball HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises union type-punning (float<->uint32 aliased reinterpret) in the Quake
   fast-inverse-sqrt bit hack. */
#include "../../65816/metaball.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = metaball_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
