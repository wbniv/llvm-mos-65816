/* Corpus slice: sobel HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   Signed 3x3 Sobel MAC + saturating magnitude via __builtin_elementwise_add_sat/_sub_sat
   (G_SADDSAT/G_USUBSAT). Distinct from #57 medfilt (compare-exchange, no MAC). */
#include "../../65816/sobel.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = sobel_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
