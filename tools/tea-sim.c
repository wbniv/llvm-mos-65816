/* Host oracle for the TEA cipher differential gate.
 * Build: cc -O2 -I examples/65816 tools/tea-sim.c -o build/tea-sim
 */
#include <stdio.h>
#include "tea.h"

int main(void) {
    uint16_t h = tea_gate_crc();
    printf("tea gate  N=%u plaintexts x %u rounds  hash=0x%04X\n",
           (unsigned)TEA_GATE_N, (unsigned)TEA_ROUNDS, (unsigned)h);
    return 0;
}
