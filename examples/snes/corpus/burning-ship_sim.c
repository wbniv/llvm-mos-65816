/* Corpus slice: Burning Ship gate CRC, HAL-free. Differential engine (dev/run.sh corpus-a16) checks
 * it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/burning_ship.h with the renderer (examples/snes/burning-ship.c) and the host
 * oracle (tools/burning-ship-sim.c). */
#include "../../65816/burning_ship.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bs_gate_crc();
    for (;;) {}
    return 0;
}
