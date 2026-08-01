/* Corpus slice: 32-point DIT FFT gate, HAL-free.
 * Differential engine checks 5 ways: host == default == +mos-a16 == +mos-xy16
 * on MAME + bsnes-jg, -verify clean. Golden: build/fft-sim → 0x6D7A
 */
#include "../../65816/fft.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = fft_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
