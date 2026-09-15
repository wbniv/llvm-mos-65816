/* Corpus slice: bsearchviz HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster B, the `bsearch` callback-ABI guard: a strictly increasing key table probed
   with a fixed query set of hits AND deliberate misses, where each call returns a void* INTO
   the array (or NULL) that the caller must difference back into an index. `bsearch` is used
   ZERO times across demos #1-#141 — qsort (15x) is the only comparator-callback libc the
   battery links, and its comparator drives a SWAP and permutes in place rather than driving
   an interval bisection and returning a pointer.
   The CRC folds only the portable part (found index / miss sentinel); the probe trace is
   deliberately NOT folded, because C does not specify how bsearch bisects and the host and
   target libcs are separate implementations. dev/bsearchviz.sh asserts the well-defined half
   instead: bs_verify_indices() re-derives every recovered index from the key table, so a
   wrong pointer->index conversion fails the gate.
   Host oracle: tools/bsearchviz-sim.c.
   See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md. */
#include "../../65816/bsearchviz.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bsearchviz_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
