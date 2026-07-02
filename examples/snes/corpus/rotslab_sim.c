/* Corpus slice: rotslab HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 xy16 index-width fix) via a
   hand-written three-reversal rotate of a >256-entry uint16_t buffer — 16-bit-indexed loads/
   stores crossing the M/X width-flag boundary, NO memmove libcall (the #93 angle differs).
   See docs/plans/2026-07-02-94-snes-rotslab.md. */
#include "../../65816/rotslab.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = rotslab_gate_crc();
    for (;;) {}
    return 0;
}
