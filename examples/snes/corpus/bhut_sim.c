/* Corpus slice: Barnes-Hut quadtree gate, HAL-free.
 * Differential engine checks 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify clean. Golden: build/bhut-sim → 0xEF0B
 */
#include "../../65816/bhut.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bh_gate_crc();
    for (;;) {}
    return 0;
}
