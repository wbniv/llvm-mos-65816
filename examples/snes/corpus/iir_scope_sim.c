/* Corpus slice: iir-scope HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Stresses a recursive IIR feedback dependency chain (y[n] from y[n-1], y[n-2]). */
#include "../../65816/iir_scope.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = iir_scope_gate_crc();
    for (;;) {}
    return 0;
}
