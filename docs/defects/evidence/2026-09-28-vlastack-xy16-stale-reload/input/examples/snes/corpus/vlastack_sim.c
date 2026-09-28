/* Corpus slice: vlastack HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster A, the G_DYN_STACKALLOC guard (MOSLegalizerInfo.cpp:456, `.custom()`):
   an RLE scanline decoder whose per-row scratch array is a VLA sized by the run count read
   out of the compressed stream, declared in the loop body so the soft SP is adjusted and
   restored once per row with a different delta. Zero demos #1-#141 form G_DYN_STACKALLOC —
   #68 polyfill's VLA const-folds to a fixed alloca, covering only G_STACKSAVE/RESTORE.
   Host oracle: tools/vlastack-sim.c.
   See docs/plans/2026-09-16-round8-unentered-backend-paths.md. */
#include "../../65816/vlastack.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = vlastack_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
