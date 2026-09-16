/* Corpus slice: ovmatrix HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster C, the OVERFLOW-BUILTIN MATRIX: all three builtins at all three widths with
   both signednesses — {add, sub, mul} x {16, 32, 64} x {unsigned, signed} = 18 cells — in ONE
   noinline kernel, every operand from runtime state and every result live across the others,
   so G_UADDO/G_SADDO, G_USUBO/G_SSUBO and G_UMULO/G_SMULO are selected and register-allocated
   next to each other under real pressure. #44, #76, #101 and #144 each test one family, at one
   or two widths, in a loop of its own; none of them tests the interaction.
   MEASURED: a probe with one CONSTANT operand per builtin folded cells away outright and lost
   G_SSUBO entirely — hence both operands runtime, and a gate that asserts every one of the 18
   cells fired BOTH outcomes (overflow and clean) at least once.
   Host oracle: tools/ovmatrix-sim.c.
   See docs/plans/2026-09-16-round8-cluster-c-boundary-and-width-escalations.md. */
#include "../../65816/ovmatrix.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = ovmatrix_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
