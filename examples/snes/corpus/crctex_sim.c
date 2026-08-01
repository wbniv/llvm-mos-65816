/* Corpus slice: crctex HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises a 256-entry const ROM look-up table indexed per byte (CRC32). */
#include "../../65816/crctex.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = crctex_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
