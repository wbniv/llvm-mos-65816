/* Corpus slice: raycaster gate CRC, HAL-free. Differential engine (dev/run.sh corpus-a16) checks it
 * 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/raycaster.h with the renderer (examples/snes/raycaster.c) and the host
 * oracle (tools/raycaster-sim.c). */
#include "../../65816/raycaster.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = rc_gate_crc();
    for (;;) {}
    return 0;
}
