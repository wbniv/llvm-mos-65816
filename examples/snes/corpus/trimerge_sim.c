/* Corpus slice: trimerge HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0016 (#46) with the three-way-compare result used AS CONTROL FLOW: a 2-input
   merge branches on the sign of (a>b)-(a<b) — advance-left / emit-both / advance-right — at s32 and
   s64, via noinline comparators that keep G_SCMP alive.
   See docs/plans/2026-07-02-99-snes-trimerge.md. */
#include "../../65816/trimerge.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = trimerge_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
