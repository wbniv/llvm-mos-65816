/* Corpus slice: packrec HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster B, the packed-record LAYOUT INVARIANT guard: a packed binary telemetry
   stream with two record shapes of coprime odd sizes (7 and 10 bytes) selected by a tag byte,
   parsed live out of a byte blob through a computed record pointer, so every wide member is
   read from an offset the compiler cannot fold to a known alignment.
   REFRAMED, honestly: on MOS every scalar already has ABI alignment 1, so an unpacked struct
   has no padding to remove and __attribute__((packed)) is a LAYOUT NO-OP — there is no second
   lowering to enter (Round 8's second negative result). What this slice guards instead is the
   padding-free-layout invariant itself, which no demo across #1-#141 asserts and on which
   every binary-format parse built with this toolchain depends; the header carries the
   _Static_assert block that pins it.
   Host oracle: tools/packrec-sim.c.
   See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md. */
#include "../../65816/packrec.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = packrec_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
