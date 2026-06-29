/* Host oracle for the #21 SNES soft-float Mandelbrot demo: prints the differential gate hash
 * (mf_gate_crc() from examples/65816/mandel-float.h, compiled host-side as IEEE-754 single
 * precision). dev/mandel-float.sh captures this as EXPECT and asserts the on-console corpus_result
 * (bsnes-jg + MAME) matches it bit-for-bit. Built with -ffp-contract=off so no FMA contraction can
 * diverge the host from the target's separate soft-float libcalls. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/mandel-float.h"

int main(void) {
    printf("mandel-float gate_crc = 0x%04X\n", mf_gate_crc());
    return 0;
}
