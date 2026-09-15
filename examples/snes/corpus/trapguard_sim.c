/* Corpus slice: trapguard HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster B, the G_TRAP guard (MOSLegalizerInfo.cpp:448, `.custom()`; legalizeTrap
   emits an RTLIB::ABORT libcall, so it lands as `jsr abort`): a dense (state, event)
   transition machine with 20 legal pairs enumerated as case labels and 4 impossible ones
   falling to a `default: __builtin_trap()`. The generator consults a per-state legality mask
   so an impossible pair never occurs, but tg_step is noinline and parameterised so the
   compiler cannot prove the default dead and the trap survives to the ROM.
   __builtin_trap / __builtin_unreachable are used ZERO times across demos #1-#141.
   HONEST FRAMING: a trap terminates, so it can never be TAKEN in a gate run — this is a
   PRESENCE-AND-INERTNESS probe, weaker than #142-#145. The CRC folds only the reachable state
   trace, the per-state visit counts and the per-pair transition counts; the structure gate is
   what asserts G_TRAP is formed and `jsr abort` reached the ROM.
   Host oracle: tools/trapguard-sim.c.
   See docs/plans/2026-09-16-round8-cluster-b-conversion-comparison-layout.md. */
#include "../../65816/trapguard.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = trapguard_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
