/* Corpus slice: scopeguard HAL-free. host==default==+mos-a16==+mos-xy16, -verify clean.
   __attribute__((cleanup(fn))) scope-exit fan-out (CGDecl.cpp:2254): guarded locals run
   their cleanup at every scope exit (fall-through, return, break, nested-block close), in
   reverse declaration order. First battery demo using the cleanup attribute. */
#include "../../65816/scopeguard.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = scopeguard_gate_crc(); for (;;) {} return 0; }
