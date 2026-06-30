/* Corpus slice: Hilbert curve d2xy/xy2d gate, HAL-free.
 * Differential engine checks 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify clean. Golden: build/hilbert-sim → 0x5999
 */
#include "../../65816/hilbert.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = hilbert_gate_crc();
    for (;;) {}
    return 0;
}
