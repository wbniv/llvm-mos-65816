/* Corpus slice: medfilt HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises branchless min/max (median-of-9 network -> G_UMIN/G_UMAX .lower @272) + abs (G_ABS @281). */
#include "../../65816/medfilt.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = medfilt_gate_crc(); for(;;){} return 0; }
