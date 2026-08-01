/* Corpus slice: editdist HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises a 2-D dynamic-programming table (Levenshtein): D[i][j] min-recurrence + backtrack. */
#include "../../65816/editdist.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = editdist_gate_crc(); for (;;) __asm__ volatile("wai"); return 0; }
