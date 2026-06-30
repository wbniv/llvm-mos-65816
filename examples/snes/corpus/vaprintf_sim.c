/* Corpus slice: vaprintf gate, HAL-free.
 * Differential engine checks 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify clean. Golden: build/vaprintf-sim → 0xE1F3
 */
#include "../../65816/vaprintf.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = vaprintf_gate_crc();
    for (;;) {}
    return 0;
}
