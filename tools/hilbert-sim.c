/* Host oracle for the Hilbert curve differential gate.
 * Build: cc -O2 -I examples/65816 tools/hilbert-sim.c -o build/hilbert-sim
 */
#include <stdio.h>
#include "hilbert.h"

int main(void) {
    uint16_t h = hilbert_gate_crc();
    printf("hilbert gate  ORDER=%u  %u pts  hash=0x%04X\n",
           (unsigned)HILBERT_ORDER, (unsigned)HILBERT_NPTS, (unsigned)h);
    return 0;
}
