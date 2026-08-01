/* Corpus slice: packed-bitfield Truchet gate, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Shares examples/65816/truchet.h with the renderer (examples/snes/truchet.c) and the host oracle.
 *
 * The gate (tr_gate_crc) packs each cell into a uint16_t bitfield struct and runs a wave sim that
 * reads/writes those fields thousands of times, folding the EXTRACTED field values into a CRC -> a pure
 * test of bitfield insert/extract codegen (mask/shift/merge), robust to packing layout. No far pointers
 * -> full 5-way bar. */
#include "../../65816/truchet.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = tr_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
