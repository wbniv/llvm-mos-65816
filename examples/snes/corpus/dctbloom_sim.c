/* Corpus slice: dctbloom HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   8x8 separable integer DCT: int32 16x16->32 MAC (__mulsi3) + signed ashr descale + narrow
   (G_ASHR + G_SEXT_INREG). Distinct from #25 fft (radix-2 butterflies/twiddles). */
#include "../../65816/dctbloom.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = dctbloom_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
