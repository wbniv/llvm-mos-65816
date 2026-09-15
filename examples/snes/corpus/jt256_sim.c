/* Corpus slice: jt256 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster A, the >128-successor jump-table guard: legalizeBrJt
   (MOSLegalizerInfo.cpp:443 / ~3311) picks between `JMP (abs,X)` and a split low/high
   byte-table + G_BRINDIRECT on `Table.MBBs.size() <= 128`. All five jump tables in demos
   #1-#141 take the first arm; ISA-256's 256-way dispatch structurally cannot, so this is
   the first program in the project to compile the second.
   Host oracle: tools/jt256-sim.c (gate CRC 0x0000 — filled from the oracle).
   See docs/plans/2026-09-16-round8-unentered-backend-paths.md. */
#include "../../65816/jt256.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = jt256_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
