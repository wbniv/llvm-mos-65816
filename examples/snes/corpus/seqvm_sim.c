/* Corpus slice: seqvm HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises the sparse-switch opcode dispatch (comparison-tree lowering). */
#include "../../65816/seqvm.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = seqvm_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
