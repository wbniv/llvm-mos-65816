/* Corpus slice: rotkal HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_ROTL/G_ROTR byte/16-bit custom lowering via
   __builtin_rotateleft8/right8/rotateleft16 with BOTH constant (per-ring) and
   runtime (outer word) amounts.  legalizeShiftRotate 1029-1254,
   S8 special 1167-1178, ConstantAmt 1046-1061. */
#include "../../65816/rotkal.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = rotkal_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
