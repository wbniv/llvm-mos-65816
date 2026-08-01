/* Corpus slice: gf256 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises GF(2^8) carryless multiply (log/antilog tables + XOR, no carry chain) and
   Reed-Solomon syndrome evaluation (Horner in GF). Cross-checked against a slow bit-by-bit
   carryless multiply inside the gate. */
#include "../../65816/gf256.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = gf256_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
