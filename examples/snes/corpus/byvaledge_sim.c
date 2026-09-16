/* Corpus slice: byvaledge HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster C, the >32-bit BY-VALUE ABI BOUNDARY compiled from both sides in one
   program: classifyArgumentType (clang Targets/MOS.cpp) sends an aggregate indirect with
   ByVal=false when getTypeSize(Ty) > 32 and direct otherwise, so a 4-byte record and a 5-byte
   record sit on opposite sides of a one-byte difference. Three shapes travel through stages
   that each MUTATE their own parameter, and the driver re-reads its own original after every
   call — the only way a missing call-site copy is observable at all, since it corrupts the
   CALLER silently and leaves the callee's own result correct. #145 bigbyval is 144 bits, far
   past the threshold; #26 boids is 32 bits, at it, with no indirect sibling in the same ROM.
   MEASURED CORRECTION: getTypeSize is in BITS and a MOS record is always a whole number of
   bytes, so there is no 33-bit size class — a record declaring 33 bits of bitfield is sizeof 5
   (40 bits) and takes the indirect path. The boundary is sizeof 4 vs sizeof 5.
   Host oracle: tools/byvaledge-sim.c.
   See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md. */
#include "../../65816/byvaledge.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = byvaledge_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
