/* Corpus slice: jtedge HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster C, the JUMP-TABLE BOUNDARY: three noinline dispatchers over the same sixteen
   handler families with 127, 128 and 129 distinct successors, so both arms of legalizeBrJt and
   the exact `Table.MBBs.size() <= 128` test (MOSLegalizerInfo.cpp:3334) are compiled side by
   side in one program. All three are fed the SAME opcode stream, restricted to 0..126 so every
   opcode is in range for all three, over three independent copies of the same VM state — a
   boundary off-by-one that mis-indexed either arm by one slot lands in a neighbouring handler
   and moves exactly one of the three. #142 jt256 sits at 256, deep past the boundary; no test
   in the tree sat anywhere near it before this one.
   Host oracle: tools/jtedge-sim.c.
   See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md. */
#include "../../65816/jtedge.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = jtedge_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
