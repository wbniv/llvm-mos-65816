/* Corpus slice: hull HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises signed 2-D cross-product orientation tests (gift-wrap convex hull). */
#include "../../65816/hull.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = hull_gate_crc(); for(;;){} return 0; }
