/* Corpus slice: pcooker HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0011 (scavenger-$p): a giant straight-line 32-bit fixed-point expression whose
   compare's N/Z is consumed AFTER several __mulsi3/__divsi3 calls (compare live across the
   call-clobber) under a dozen live 32-bit temps. a16/xy16 legs are load-bearing (0011 accum-gated).
   See docs/plans/2026-07-02-109-snes-pcooker.md. */
#include "../../65816/pcooker.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = pcooker_gate_crc(); for(;;){} return 0; }
