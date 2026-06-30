/* Corpus slice: cardioid times-table modulo kernel, HAL-free.
 * The differential engine (dev/run.sh corpus-a16) checks it 5 ways:
 *   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/cardioid.h with the renderer (examples/snes/cardioid.c)
 * and the host oracle (tools/cardioid-sim.c), so they can never drift.
 * Golden value from: cc -O2 -I examples/65816 tools/cardioid-sim.c -o /tmp/cs && /tmp/cs
 */
#include "../../65816/cardioid.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = card_gate_crc();
    for (;;) {}
    return 0;
}
