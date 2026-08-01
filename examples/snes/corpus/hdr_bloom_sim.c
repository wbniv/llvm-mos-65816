/* Corpus slice: hdr-bloom HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Stresses saturating / overflow-checked add (__builtin_add_overflow → adc; bcs). */
#include "../../65816/hdr_bloom.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = hdr_bloom_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
