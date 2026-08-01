/* Corpus slice: multibase HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises libc div()/lldiv() returning div_t/lldiv_t BY VALUE (aggregate-return ABI + G_SDIVREM). */
#include "../../65816/multibase.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = multibase_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
