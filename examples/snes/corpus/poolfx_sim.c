/* Corpus slice: poolfx HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises a manual free-list pool allocator (alloc pops / free pushes a LIFO free list
   threaded through the slots), driven by a particle-fountain birth/death cycle. */
#include "../../65816/poolfx.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = poolfx_gate_crc();
    for (;;) {}
    return 0;
}
