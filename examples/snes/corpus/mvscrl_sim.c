/* Corpus slice: mvscrl HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_MEMMOVE descending (dst>src overlapping) and ascending (dst<src)
   paths via memmove(upper+1,upper,7×16) and memmove(lower,lower+1,7×16).
   SDK memmove (mos-platform/common/c/mem.c:15). */
#include "../../65816/mvscrl.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = mvscrl_gate_crc();
    for (;;) {}
    return 0;
}
