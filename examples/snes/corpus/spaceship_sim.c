/* Corpus slice: spaceship HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0016 (#46 G_SCMP three-way compare) at s16/s32/s64 via qsort callbacks
   returning (a>b)-(a<b) at int8/int16/int32/int64 keys.
   See docs/plans/2026-07-02-97-snes-spaceship.md. */
#include "../../65816/spaceship.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = spaceship_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
