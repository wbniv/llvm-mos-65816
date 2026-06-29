/* Corpus slice: harmonograph gate CRC, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/harmonograph.h with the renderer (examples/snes/harmonograph.c) and the
 * host oracle (tools/harmonograph-sim.c).
 *
 * harmo_gate_crc()'s state/params are static (in .bss) to avoid a large soft-stack frame. */
#include "../../65816/harmonograph.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = harmo_gate_crc();
    for (;;) {}
    return 0;
}
