/* Corpus slice: perlin HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises fixed-point Perlin gradient noise: perm table + fade polynomial + gradient dot + lerp. */
#include "../../65816/perlin.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = perlin_gate_crc(); for(;;){} return 0; }
