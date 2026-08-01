/* Corpus slice: sbitfld HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_SEXT_INREG via signed bitfield read-back:
     int16_t height:5 / slope:4 / flow:4 in SBCell struct.
   Distinct from #29b truchet (uint16_t bitfields → no sext) and
   #52 disbits (uint32_t unsigned bitfields → zero-extend). */
#include "../../65816/sbitfld.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = sbitfld_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
