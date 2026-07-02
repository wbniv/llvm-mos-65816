/* Corpus slice: oddmask HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses the odd-width G_ANYEXT routing of patch 0017 (#61 dhmix, legalizeAnyExt→zext): forms
   s20/s24/s40/s48 intermediates by masking 64-bit values, then s64 arithmetic — the a16/xy16 legs
   are load-bearing (dhmix crashed there on G_ANYEXT s24 before the fix).
   See docs/plans/2026-07-02-103-snes-oddmask.md. */
#include "../../65816/oddmask.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = oddmask_gate_crc();
    for (;;) {}
    return 0;
}
