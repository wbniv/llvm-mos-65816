/* Corpus slice: permscat HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 xy16 index-width fix) at its
   hardest: a scatter dst[perm[i]]=src[i] over a >512-entry grid with TWO live 16-bit indices (the
   loop counter i and the data-dependent scatter index perm[i]) — the shape a stray sep #$10 zeroes.
   See docs/plans/2026-07-02-95-snes-permscat.md. */
#include "../../65816/permscat.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = permscat_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
