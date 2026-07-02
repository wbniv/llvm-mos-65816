/* Corpus slice: modexp256 HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Re-stresses patch 0017's s64 (un)merge glue (#61 dhmix) as a high-volume regression guard: a
   256-bit Diffie-Hellman modexp built from uint32[8] limbs + uint64 multiply-accumulate. The DH
   identity A^b==B^a (folded as a mismatch witness) catches any s64-lane-split miscompile.
   See docs/plans/2026-07-02-104-snes-modexp256.md. */
#include "../../65816/modexp256.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = modexp256_gate_crc();
    for (;;) {}
    return 0;
}
