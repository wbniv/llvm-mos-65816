/* Corpus slice: backtrack HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 6 Cluster G, the FLAGSHIP guard for the 65816-native platforms/snes/setjmp.S fix
   (bug #35): an 8-queens search whose every recursion level owns a setjmp choice point and
   whose every dead end longjmps straight back to the deepest still-viable ancestor, unwinding
   several jsr frames at once from a varying depth. corpus/setjmp_sim.c covers the minimum
   (one frame, one jump); this covers the multi-frame unwind that a page-1-S-reconstruct or
   soft-SP/CSR-restore defect would corrupt.
   NOT YET IN expected.tsv — deliberately. It is blocked on an OPEN runtime defect this slice
   found on its first run: longjmp's page-1 hard-stack reconstruction never executes, so every
   longjmp leaves S in page 0 and any return out of the setjmp frame rts-es into the zero page.
   Root cause + minimal repro + evidence:
   docs/investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md
   Add the manifest row (host oracle 0x7336, tools/backtrack-sim.c) when that lands.
   See docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md. */
#include "../../65816/backtrack.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = backtrack_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
