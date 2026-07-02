/* Corpus slice: plyoracle HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   Negamax + alpha-beta tic-tac-toe: negate-on-return (G_SUB 0,x) + running G_SMAX + alpha-beta
   cutoff prune CFG — alternating-sign recursion #17/#18 never form. */
#include "../../65816/plyoracle.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = plyoracle_gate_crc(); for (;;) {} return 0; }
