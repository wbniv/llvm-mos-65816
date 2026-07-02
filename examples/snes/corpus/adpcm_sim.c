/* Corpus slice: adpcm HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   IMA-ADPCM decoder: G_SADDSAT/G_SSUBSAT (saturating predictor clamp) inside a serial
   feedback loop + step-index LUT walk. Distinct from #48 IIR (wrapping) / #67 huffman. */
#include "../../65816/adpcm.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = adpcm_gate_crc(); for (;;) {} return 0; }
