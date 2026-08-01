/* Corpus slice: double-pendulum chaos (#14 compiler stress-test).
 * Differential engine (dev/run.sh corpus-a16) checks it 5 ways:
 *   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg
 * Shares examples/65816/dpend.h with the host oracle and the renderer.
 *
 * State in .bss (not soft-stack) so the corpus environment's shallow stack is not an issue.
 * Codegen under test: __mulsi3 (ω² coupling), __divsi3 (D denominator), rep/sep (a16). */
#include <stdint.h>

volatile uint16_t corpus_result;

#include "../../65816/dpend.h"

int main(void) {
    corpus_result = dpend_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
