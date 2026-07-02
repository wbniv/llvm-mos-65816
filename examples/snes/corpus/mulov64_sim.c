/* Corpus slice: mulov64 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_UMULO/G_SMULO at s64 (lowerMulo) -> G_UMULH/G_SMULH at s64 (.lower()),
   the one untested s64 legalizer path (see docs/plans/2026-07-02-101-snes-mulov64.md). */
#include "../../65816/mulov64.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = mulov64_gate_crc();
    for (;;) {}
    return 0;
}
