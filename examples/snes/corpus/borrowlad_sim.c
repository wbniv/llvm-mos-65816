/* Corpus slice: borrowlad HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0012 (LDCImm-set): a 128-bit descending odometer built from chained 16-bit
   subtracts-with-borrow whose carry-in is a set/clear i1 (LDCImm 1). a16/xy16 legs load-bearing.
   See docs/plans/2026-07-02-110-snes-borrowlad.md. */
#include "../../65816/borrowlad.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = borrowlad_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
