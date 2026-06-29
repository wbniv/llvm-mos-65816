/* Corpus slice: 64-bit hash/avalanche gate, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/avalanche.h with the renderer (examples/snes/avalanche.c) and the host
 * oracle (tools/avalanche-sim.c).
 *
 * The gate (h64_gate_crc) chains 256 splitmix64 steps with 64-bit xor/add/shift/divide and folds the
 * 64-bit accumulator into a 16-bit CRC — no pointers, far or otherwise, so it is a full 5-way test of
 * the 64-bit integer libcalls (__muldi3/__lshrdi3/__ashldi3/__udivdi3/__adddi3). 64-bit ops are exact,
 * so host (native u64) and target (4x16 libcalls) must agree bit-for-bit. */
#include "../../65816/avalanche.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = h64_gate_crc();
    for (;;) {}
    return 0;
}
