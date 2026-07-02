/* Corpus slice: truncstair HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_FPTOSI via (int16_t)x_f → __fixsfsi (float→int, trunc toward zero)
   and G_SITOFP via (float)q → __floatsisf (int→float).
   Documents the floorf/ceilf/truncf .unsupported() SDK gap: those symbols don't
   exist in the MOS SDK; (float)(int)x achieves truncf via inline conversion. */
#include "../../65816/truncstair.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = truncstair_gate_crc();
    for (;;) {}
    return 0;
}
