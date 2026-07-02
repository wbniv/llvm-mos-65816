/* Corpus slice: matcascade HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   sret hidden-pointer struct-return ABI: mat2 (8 bytes, over getNaturalAlignIndirect
   threshold MOS.cpp:88) returned by value from chained mat_mul. Distinct from #26 boids
   (vec2 32-bit register-pair return, not sret). */
#include "../../65816/matcascade.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = matcascade_gate_crc(); for (;;) {} return 0; }
