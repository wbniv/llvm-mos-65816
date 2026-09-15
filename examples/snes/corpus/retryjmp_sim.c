/* Corpus slice: retryjmp HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 6 Cluster G, the RE-ENTRY guard for the 65816-native platforms/snes/setjmp.S fix
   (bug #35): ONE setjmp site, re-armed and re-entered 24 times, each attempt jumping back from a
   different call depth with a different soft-stack high-water mark. rj_work() is noinline and
   recursive with six 16-bit locals live across its recursive call, so every level is a real jsr
   frame over a real soft-stack frame. The page-1 S reconstruct, the soft-SP restore and the
   return-address rewrite therefore interact on EVERY retry, and state that leaks across
   re-entries drifts the outcome sequence rather than corrupting one value.
   Host oracle: tools/retryjmp-sim.c (gate CRC 0x3388).
   NOT IN expected.tsv — deliberately. This slice found an OPEN +mos-xy16 miscompile on its first
   run: the frame-index address materialization for a spill slot takes the live Imag16 pair that
   holds the value about to be stored, so rj_result[] receives the index expression instead
   (default and +mos-a16 are correct; xy16 gives 0x82D4 against the host's 0x3388). The slice
   stays here as the reproduction. Root cause, assembly and reduction:
   docs/investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md
   Add the manifest row, dev/retryjmp.sh and the visual ROM once that is fixed.
   See docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md. */
#include "../../65816/retryjmp.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = retryjmp_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
