/* Corpus slice: bignum factorial (#20), HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg,
 * -verify-machineinstrs clean. Shares examples/65816/factorial.h with the renderer
 * (examples/snes/factorial.c) and the host oracle (tools/factorial-sim.c).
 *
 * State is static (in .bss) to avoid a ~1.4 KB soft-stack frame for bignum_state. */
#include <stdint.h>

volatile uint16_t corpus_result;

#include "../../65816/factorial.h"

int main(void) {
    corpus_result = factorial_gate_crc();
    for (;;) {}
    return 0;
}
