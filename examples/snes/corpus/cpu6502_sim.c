/* Corpus slice: cpu6502 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   6502/65C02 CPU simulator stress-test: 256-entry switch dispatch, uint16_t PC
   arithmetic, uint8_t flag bit-manipulation, and indexed array reads.
   See docs/plans/2026-07-02-102-snes-cpu6502.md. */
#include "../../65816/cpu6502.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = cpu6502_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
