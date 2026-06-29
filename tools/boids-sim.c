/* Host oracle for the #26 SNES Boids demo: prints the differential gate hash (boids_gate_crc() from
 * examples/65816/boids.h, compiled host-side). dev/boids.sh captures this as EXPECT and asserts the
 * on-console corpus_result (bsnes-jg + MAME) matches it bit-for-bit. All math is exact integer
 * fixed-point, so no contraction/rounding caveats apply — the only variable under test is the
 * aggregate-return (struct-by-value) ABI the steering kernel exercises. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/boids.h"

int main(void) {
    printf("boids gate_crc = 0x%04X\n", boids_gate_crc());
    return 0;
}
