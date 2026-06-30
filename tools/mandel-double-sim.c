/* Host oracle for the #33 SNES DOUBLE-precision soft-float Mandelbrot demo: prints the differential gate
 * hash (md_gate_crc() from examples/65816/mandel-double.h, compiled host-side as IEEE-754 double
 * precision). dev/mandel-double.sh captures this as EXPECT and asserts the on-console corpus_result
 * (bsnes-jg + MAME) matches it bit-for-bit. Built with -ffp-contract=off so no FMA contraction can
 * diverge the host from the target's separate 64-bit soft-float libcalls. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/mandel-double.h"

int main(void) {
    printf("mandel-double gate_crc = 0x%04X\n", md_gate_crc());
    return 0;
}
