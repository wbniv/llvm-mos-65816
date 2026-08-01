/* Corpus slice: uarteye HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-bit coalescer miscompile) via a software
   UART framing loop: a byte shifted out of a carry-rotated TX register and into a carry-rotated RX
   register (two loop-carried shift registers). DEFAULT-8-bit leg is load-bearing (0010 not accum-gated).
   See docs/plans/2026-07-02-108-snes-uarteye.md. */
#include "../../65816/uarteye.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = uarteye_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
