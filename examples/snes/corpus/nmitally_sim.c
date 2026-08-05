/* Corpus slice: #123 nmitally, HAL-free. Differential engine (dev/run.sh corpus-a16) checks it
 * 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify-machineinstrs clean.
 *
 * This slice runs the ORACLE form — the same work_step/isr_step/fold sequence, executed
 * sequentially with no interrupts — so it isolates the ARITHMETIC half of the differential.
 * The interrupt half (a real __attribute__((interrupt)) handler driving the same steps at v-blank
 * behind the arm/service/clear fence) lives in examples/snes/nmitally.c and is asserted by
 * dev/nmitally.sh against the same host oracle. Both must land on the same CRC. */
#include "../../65816/nmitally.h"

volatile uint16_t corpus_result;

int main(void) {
    uint32_t wide;
    corpus_result = nmitally_model((uint16_t)NMITALLY_FRAMES, &wide);
    for (;;) __asm__ volatile("wai");
    return 0;
}
