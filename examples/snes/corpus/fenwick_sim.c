/* Corpus slice: fenwick HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises the Fenwick/BIT i&-i low-bit-isolation trick in dynamic prefix-sum loops. */
#include "../../65816/fenwick.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = fenwick_gate_crc(); for(;;){} return 0; }
