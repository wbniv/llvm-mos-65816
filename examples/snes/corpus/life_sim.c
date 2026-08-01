/* Corpus slice: Conway's Game of Life gate CRC, HAL-free. Differential engine
 * (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify-machineinstrs clean.
 * Shares examples/65816/life.h with the renderer (examples/snes/life.c) and the
 * host oracle (tools/life-sim.c).
 *
 * ga[]/gb[] inside life_gate_crc() are static (in .bss) to avoid a large soft-stack frame. */
#include "../../65816/life.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = life_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
