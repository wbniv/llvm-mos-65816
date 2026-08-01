/* Corpus slice: lfsr2 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-bit coalescer miscompile) via TWO
   loop-carried 8-bit LFSRs (Galois + Fibonacci) + a 16-bit Galois, stepped simultaneously — the
   DEFAULT-8-bit leg is the load-bearing one (0010 is not accum-gated).
   See docs/plans/2026-07-02-106-snes-lfsr2.md. */
#include "../../65816/lfsr2.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = lfsr2_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
