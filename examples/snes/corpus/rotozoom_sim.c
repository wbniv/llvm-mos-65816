/* Corpus slice: rotozoom HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises the widening multiply-high (Q16.16 q16mul = (int64)a*b>>16, G_SMULH .lower via __muldi3). */
#include "../../65816/rotozoom.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = rotozoom_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
