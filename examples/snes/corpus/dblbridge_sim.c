/* Corpus slice: dblbridge HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster B, the G_FPEXT S32->S64 / G_FPTRUNC S64->S32 guard (MOSLegalizerInfo.cpp:375
   / :376, both .libcallFor -> __extendsfdf2 / __truncdfsf2): the same chaotic map iterated
   two ways over identical binary32 state — once wholly at float, once PROMOTED to double for
   the step and DEMOTED back each iteration — so the two lanes differ only in where the
   rounding happens and the step at which they separate is the measured output. ZERO corpus
   slices across demos #1-#141 link either conversion symbol; #57 mandel-double uses double
   throughout but only ever forms __floatunsidf (integer->double).
   Correctly-rounded IEEE only (+ - * and the two conversions) — no libm, nothing
   implementation-defined; the CRC folds raw uint32 bit patterns.
   Host oracle: tools/dblbridge-sim.c (compiled -ffp-contract=off).
   See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md. */
#include "../../65816/dblbridge.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = dblbridge_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
