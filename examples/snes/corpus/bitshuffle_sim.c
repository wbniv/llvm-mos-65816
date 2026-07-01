/* Corpus slice: bitshuffle HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises the byte-swap / bit-reverse intrinsics: __builtin_bswap32 (-> __bswapsi2)
   and __builtin_bitreverse32 (-> G_BITREVERSE .lower()). */
#include "../../65816/bitshuffle.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bitshuffle_gate_crc();
    for (;;) {}
    return 0;
}
