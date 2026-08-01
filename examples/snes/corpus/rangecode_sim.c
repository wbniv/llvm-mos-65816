/* Corpus slice: rangecode HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   Binary arithmetic (range) coder: interval split bound=(range>>PBITS)*prob (__mulsi3+G_LSHR)
   + byte-wise renormalize carry loop (32-bit G_SHL/G_LSHR). Distinct from #67 huffman/#49 lzdec. */
#include "../../65816/rangecode.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = rangecode_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
