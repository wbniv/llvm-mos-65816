/* Corpus slice: ucmprank HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses the UNSIGNED half of patch 0016 (#46): qsort with unsigned spaceship comparators
   (a>b)-(a<b) at uint16/uint32/uint64 forces G_UCMP at u16/u32/u64 (→ lowerThreewayCompare) — the
   unsigned three-way lowering no prior demo emitted (#46/#97 were signed G_SCMP).
   See docs/plans/2026-07-02-98-snes-ucmprank.md. */
#include "../../65816/ucmprank.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = ucmprank_gate_crc();
    for (;;) {}
    return 0;
}
