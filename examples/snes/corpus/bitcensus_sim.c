/* Corpus slice: bitcensus HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises the bit-population intrinsic family: __builtin_popcountll/clzll/ctzll/parityll
   (-> __popcountdi2/__clzdi2/__ctzdi2/__paritydi2 + inline G_CTPOP/G_CTLZ/G_CTTZ). */
#include "../../65816/bitcensus.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bitcensus_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
