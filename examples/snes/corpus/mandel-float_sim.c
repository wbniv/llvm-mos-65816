/* Corpus slice: soft-float Mandelbrot escape-time gate, HAL-free. Differential engine
 * (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on
 * MAME + bsnes-jg, -verify-machineinstrs clean. Shares examples/65816/mandel-float.h with the
 * renderer (examples/snes/mandel-float.c) and the host oracle (tools/mandel-float-sim.c).
 *
 * The gate (mf_gate_crc) folds two escape buffers on a 6x6 low-WRAM grid plus a 24-step bit-exact
 * orbit witness, so it has NO far pointers and is a full 5-way test of the IEEE-754 soft-float
 * library (__mulsf3/__addsf3/__subsf3/__divsf3/__gtsf2/__floatsisf). The ROM additionally exercises
 * the far high-WRAM framebuffer for the on-screen 64x56 zoom. */
#include "../../65816/mandel-float.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = mf_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
