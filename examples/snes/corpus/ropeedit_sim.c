/* Corpus slice: ropeedit HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 xy16 index-width fix) at scale:
   a gap-buffer editor that memmoves text across the gap on every cursor move (both directions,
   >256 bytes → 16-bit offset), driven by a scripted edit stream.
   See docs/plans/2026-07-02-96-snes-ropeedit.md. */
#include "../../65816/ropeedit.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = ropeedit_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
