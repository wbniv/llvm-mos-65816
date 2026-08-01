/* Corpus slice: bitweave HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-bit coalescer miscompile) via a serial
   rotate-out/rotate-in bit-reversal carry loop (two loop-carried rev registers, an 8-bit and a
   16-bit, interleaved) — the DEFAULT-8-bit leg is load-bearing (0010 is not accum-gated).
   See docs/plans/2026-07-02-107-snes-bitweave.md. */
#include "../../65816/bitweave.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = bitweave_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
