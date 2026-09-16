/* Corpus slice: vlanest HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster C, the NESTED soft-SP unwind: two VLAs in nested block scopes with
   independent runtime lengths, both re-entered once per loop iteration so the outer
   G_STACKSAVE/G_STACKRESTORE bracket survives AS a bracket around the inner one (measured:
   the obvious shapes collapse to a single bracket). The inner length is derived from the
   OUTER allocation's contents, and the outer array is re-read after every inner block closes
   plus once more per row, because an overshooting unwind corrupts the outer array silently —
   no crash, no verifier complaint, the inner result still right.
   #143 vlastack covers ONE bracket at ONE depth; this is the depth axis.
   Host oracle: tools/vlanest-sim.c.
   See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md. */
#include "../../65816/vlanest.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = vlanest_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
