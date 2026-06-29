/* Corpus slice: Boids struct-by-value steering gate, HAL-free. Differential engine (dev/run.sh
 * corpus-a16) checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify
 * clean. Shares examples/65816/boids.h with the renderer (examples/snes/boids.c) and the host oracle
 * (tools/boids-sim.c).
 *
 * The gate (boids_gate_crc) runs a fixed seeded flock BOID_GATE_N steps through the vec2 by-value
 * steering kernel (v2_add/v2_sub/v2_scale + separation/alignment/cohesion, all noinline so the
 * aggregate-return ABI is really exercised) and folds the flock into a 16-bit CRC — no pointers, far or
 * otherwise, so it is a full 5-way test of the small-struct register-pair-vs-sret return path. Integer
 * fixed-point is exact, so host and target must agree bit-for-bit. */
#include "../../65816/boids.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = boids_gate_crc();
    for (;;) {}
    return 0;
}
