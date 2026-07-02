/* Corpus slice: crcwall HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0010 (default-8-bit coalesce-rotate-Ac miscompile) via three interleaved
   bit-serial CRC shift registers (CRC-8/16/32) under register pressure. The DEFAULT-8-bit leg is
   the load-bearing one (0010 is not accum-gated).
   See docs/plans/2026-07-02-105-snes-crcwall.md. */
#include "../../65816/crcwall.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = crcwall_gate_crc();
    for (;;) {}
    return 0;
}
