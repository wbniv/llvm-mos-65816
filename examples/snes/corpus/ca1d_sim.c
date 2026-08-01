/* Corpus slice: 1-D Cellular Automaton gate CRC, HAL-free. Differential engine
 * (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify-machineinstrs clean.
 * Shares examples/65816/ca1d.h with the renderer (examples/snes/1d-ca.c) and the
 * host oracle (tools/ca1d-sim.c).
 *
 * ga[]/gb[] are static (in .bss) to avoid a 64-byte frame on the soft stack. */
#include "../../65816/ca1d.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = ca_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
