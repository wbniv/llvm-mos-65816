/* Corpus slice: percol HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises union-find with path compression (find chases + rewrites parent pointers flat). */
#include "../../65816/percol.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = percol_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
