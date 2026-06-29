/* Corpus slice: Julia-set escape-time gate, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg,
 * -verify-machineinstrs clean. Shares examples/65816/julia.h with the renderer
 * (examples/snes/julia.c) and the host oracle (tools/julia-sim.c).
 *
 * The gate folds 16 keyframe escape buffers on a 16x16 low-WRAM grid (julia_gate_crc), so it has
 * NO far pointers and is a full 5-way test of the Q5.10 complex multiply (the buffer is a static in
 * julia.h's .bss, keeping the soft-stack frame tiny). The ROM additionally exercises the far high-
 * WRAM framebuffer for the on-screen 64x56 morph. */
#include "../../65816/julia.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = julia_gate_crc();
    for (;;) {}
    return 0;
}
