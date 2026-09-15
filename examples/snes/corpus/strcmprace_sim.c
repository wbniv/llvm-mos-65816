/* Corpus slice: strcmprace HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster B, the memcmp/strcmp/strncmp guard: fixed-width string lanes merged under a
   real lexicographic order (strcmp), then every adjacent pair re-compared by a SHORT-bounded
   strncmp and a full-width memcmp that runs past each terminator into deterministic filler,
   so the three functions genuinely disagree. All three symbols are used ZERO times tree-wide
   across demos #1-#141.
   The CRC folds the SIGN of every comparison normalised to -1/0/+1 — never the magnitude,
   which C leaves implementation-defined — plus each comparison's resolving byte position
   (computed by this header's own scan, not read out of the libc) and the final ordering.
   MEASURED NEGATIVE: MOS never inline-expands memcmp at any constant size, including the
   `== 0` form other targets specialise, so this covers three never-linked libcalls rather
   than the second lowering the ideas doc predicted.
   Host oracle: tools/strcmprace-sim.c.
   See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md. */
#include "../../65816/strcmprace.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = strcmprace_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
