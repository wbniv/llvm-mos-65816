/* Corpus slice: borrowlad HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   A 128-bit descending odometer built from chained subtracts-with-borrow. The a16/xy16 legs
   exercise native-width subtraction; patch 0012 has a separate baseline mos65c02 MIR regression.
   See docs/plans/2026-07-02-110-snes-borrowlad.md. */
#include "../../65816/borrowlad.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = borrowlad_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
