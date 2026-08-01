/* Corpus slice: radix HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises a non-comparison sort: LSD radix (histogram + prefix-sum + stable scatter, zero compares). */
#include "../../65816/radix.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = radix_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
