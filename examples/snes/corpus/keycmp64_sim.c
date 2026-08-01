/* Corpus slice: keycmp64 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0016 (#46) at the extreme width: libc qsort of records with a CHAINED
   comparator — primary int64 spaceship, tie-broken by a second int64 spaceship → G_SCMP s64 twice
   per call, with a data-dependent short-circuit (tie-break only on primary equal).
   See docs/plans/2026-07-02-100-snes-keycmp64.md. */
#include "../../65816/keycmp64.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = keycmp64_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
