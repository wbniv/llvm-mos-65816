/* Corpus slice: lzdec HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises an LZ77/LZSS byte-stream decoder copying back-references from its own output. */
#include "../../65816/lzdec.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = lzdec_gate_crc();
    for (;;) {}
    return 0;
}
