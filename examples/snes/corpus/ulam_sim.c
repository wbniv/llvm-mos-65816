/* Corpus slice: ulam HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises VARIABLE-COUNT G_SHL/G_LSHR via bit-array set `arr[i>>3] |= 1u<<(i&7)`
   (Sieve of Eratosthenes). Distinct from #5 life (fixed masks), #28 hilbert. */
#include "../../65816/ulam.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = ulam_gate_crc();
    for (;;) {}
    return 0;
}
