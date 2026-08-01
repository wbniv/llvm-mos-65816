/* Corpus slice: domcol HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises NaN/unordered float compares (__unordsf2/__eqsf2/__nesf2) at complex poles. Folds the
   COLOUR INDEX (branch outcome), never raw NaN bits. */
#include "../../65816/domcol.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = domcol_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
