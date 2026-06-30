/* Host oracle for the #29b SNES Truchet (packed bitfields) demo: prints the differential gate hash
 * (tr_gate_crc() from examples/65816/truchet.h, compiled host-side). dev/truchet.sh captures this as
 * EXPECT and asserts the on-console corpus_result (bsnes-jg) matches it. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/truchet.h"
int main(void) { printf("truchet gate_crc = 0x%04X\n", tr_gate_crc()); return 0; }
