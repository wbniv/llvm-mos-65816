/* Corpus slice: jtsparse HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster C, the THIRD switch-lowering strategy: a switch whose case values are too
   sparse to tabulate never reaches legalizeBrJt at all — it is lowered to a binary-search
   compare tree, structurally distinct from both jump-table arms (#142 jt256, #152 jtedge) and
   never deliberately forced by any prior demo. Two noinline dispatchers carry the SAME sixteen
   handler bodies — one at dense indices 0..15 (jump table), one at sparse keys 0..55555
   (compare tree) — and every logical operation runs through both over independent copies of
   the same VM state, so strategy 3 is differentially checked against strategy 1 inside one
   program. Both default arms are deliberately exercised.
   Host oracle: tools/jtsparse-sim.c.
   See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md. */
#include "../../65816/jtsparse.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = jtsparse_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
