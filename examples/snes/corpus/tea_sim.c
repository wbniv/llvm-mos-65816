/* Corpus slice: TEA cipher gate, HAL-free.
 * Differential engine checks 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify clean. Golden: cc -O2 -I examples/65816 tools/tea-sim.c -o /tmp/t && /tmp/t
 */
#include "../../65816/tea.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = tea_gate_crc();
    for (;;) {}
    return 0;
}
