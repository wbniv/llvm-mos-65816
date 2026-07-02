/* Corpus slice: ovmove HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses the #23/patch-0002 +mos-xy16 in-place-memmove REP/SEP index-width fix and
   #79's both-direction G_MEMMOVE overlap, escalated to a >256-byte buffer (16-bit index).
   See docs/plans/2026-07-02-93-snes-ovmove.md. */
#include "../../65816/ovmove.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = ovmove_gate_crc();
    for (;;) {}
    return 0;
}
