/* Corpus slice: DOUBLE-precision soft-float Mandelbrot escape-time gate, HAL-free. Differential engine
 * (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg,
 * -verify-machineinstrs clean. Shares examples/65816/mandel-double.h with the renderer
 * (examples/snes/mandel-double.c) and the host oracle (tools/mandel-double-sim.c).
 *
 * The gate (md_gate_crc) folds a DOUBLE escape buffer + a FLOAT escape buffer of the same window on a
 * 5x5 low-WRAM grid (maxiter 6), a 12-step bit-exact double orbit witness, and a double<->float
 * conversion round-trip witness — so it has NO far pointers and is a full 5-way test of the IEEE-754
 * 64-bit soft-float library (__muldf3/__adddf3/__subdf3/__divdf3/__ltdf2/__floatsidf/__fixdfsi) plus the
 * __truncdfsf2/__extendsfdf2 conversions. The ROM additionally exercises a far high-WRAM framebuffer for
 * the on-screen 64x56 float-vs-double split-screen. */
#include "../../65816/mandel-double.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = md_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
