/* Corpus slice: N-body orbits, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg,
 * -verify-machineinstrs clean.  Shares examples/65816/n-body.h with the renderer
 * (examples/snes/nbody.c) and the host oracle (tools/nbody-sim.c).
 *
 * State is static (in .bss) to avoid a soft-stack frame in the corpus environment.
 * nbody_gate_crc() allocates its own NBody array on the stack (3 bodies × 9 bytes =
 * 27 bytes) — well within the SNES soft-stack budget. */
#include "../../65816/n-body.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = nbody_gate_crc();
    for (;;) {}
    return 0;
}
