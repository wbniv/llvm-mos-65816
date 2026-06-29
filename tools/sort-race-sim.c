// Host oracle for the SNES Sorting Race demo (#17). Compiles examples/65816/sort-race.h on the
// host and prints the differential-gate CRC — the golden reference dev/sort-race.sh asserts the
// on-console corpus_result against. Build: cc -O2 -I examples/65816 tools/sort-race-sim.c
#include <stdio.h>
#include "sort-race.h"

int main(void) {
    printf("sort-race gate_crc = 0x%04X  (N=%u rounds=%u)\n",
           (unsigned)sortrace_gate_crc(), (unsigned)SR_N, (unsigned)SR_GATE_ROUNDS);
    return 0;
}
