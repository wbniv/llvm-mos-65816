/* Corpus slice: borrowov HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster A, the G_USUBO/G_SSUBO guard (MOSLegalizerInfo.cpp:296; custom cases
   :2031/:2034): a reservoir cascade whose every transfer is a checked subtract via
   __builtin_sub_overflow at uint16 (borrow out), int16 (native-width signed overflow) and
   int32 (double-width signed overflow), with underflow as a first-class rejected-transfer
   event. `__builtin_sub_overflow` appears ZERO times across demos #1-#141 — only the add
   (#44) and mul (#76/#101) forms are used, and the subtract predicates are not those
   rotated.
   Host oracle: tools/borrowov-sim.c.
   See docs/plans/2026-09-16-round8-unentered-backend-paths.md. */
#include "../../65816/borrowov.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = borrowov_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
