/* Corpus slice: cosmzoom HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises 64-bit int <-> float conversion (__floatundisf/__fixunssfdi/__floatdisf/__fixsfdi). */
#include "../../65816/cosmzoom.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = cosm_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
