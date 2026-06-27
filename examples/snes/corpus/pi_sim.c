/* Corpus slice: π spigot + Monte-Carlo, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg,
 * -verify-machineinstrs clean. Shares examples/65816/pi_spigot.h with the renderer
 * (examples/snes/spigot.c) and the host oracle (tools/pi-sim.c).
 *
 * State is static (in .bss) to avoid a 1.4KB soft-stack frame in the corpus environment.
 * pi_gate_crc() takes pointers so programs with a pre-existing pi_spigot_state in their
 * App struct (like spigot.c) can avoid a second allocation. */
#include "../../65816/pi_spigot.h"

static pi_spigot_state sp;
static mc_state mc;

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = pi_gate_crc(&sp, &mc);
    for (;;) {}
    return 0;
}
