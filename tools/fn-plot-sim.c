/* Host oracle for the fn-plot differential gate.
 * Compiles the SAME examples/65816/fn_plot.h the SNES program runs and prints the golden
 * gate CRC — the single source of truth asserted on both emulators across all modes.
 *
 * Build:  cc -O2 -std=c99 -I examples/65816 tools/fn-plot-sim.c -o build/fn-plot-sim
 */
#include <stdio.h>
#include <stdint.h>
#include "fn_plot.h"

int main(void) {
    uint16_t h = fn_gate_crc();
    printf("fn-plot gate  FN_GATE_N=%u  expr=%s  hash=0x%04X\n",
           (unsigned)FN_GATE_N, fn_exprs[0], (unsigned)h);
    return 0;
}
