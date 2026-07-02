/* Minimal reproducer for the #83 truncstair ZP-allocation miscompile (2026-07-01).
 *
 * SYMPTOM: a 16-bit accumulator `h`, folded each loop iteration and kept live
 * across a chain of soft-float libcalls (__floatsisf/__mulsf3/__fixsfsi/__subsf3),
 * computes the WRONG value ONLY when the compiler places the function's persistent
 * static ZP frame at a high address (observed $69) — which happens under the
 * whole-program ZP pressure of a real SNES ROM (display + title code linked).
 * In isolation (corpus slice, or a bare ROM with no display) the frame lands at
 * $20 and the result is correct.
 *
 *   host / corpus / bare-ROM  : 0x02CA   (frame @ $20)  CORRECT
 *   full display ROM          : 0x1EB5   (frame @ $69)  WRONG
 *
 * The generated gate-function assembly is BYTE-IDENTICAL between the passing and
 * failing builds (only BB label numbers differ) — the ONLY difference is the
 * linker-resolved base of `.Ltruncstair_gate_crc_zp_stk`. No ISR runs during the
 * computation (snes_wait_vblank is a poll loop). None of the soft-float call-tree
 * routines write $69–$74. So the corruption is a whole-program-dependent
 * ZP-allocation / aliasing defect (suspect: MOSZeroPageAlloc static-frame
 * interference analysis vs. the soft-float call tree, or a soft-stack/scratch
 * alias only reachable at the $69 placement).
 *
 * TO REPRODUCE:
 *   1. Build examples/snes/truncstair.c with +mos-a16 → corpus_result = 0x1EB5 (WRONG).
 *   2. Build examples/snes/corpus/truncstair_sim.c (same gate) → 0x02CA (CORRECT).
 *   3. diff the two LTO .s gate functions → identical but for label numbers.
 *   4. Decode the STY at gate+4 in each ROM → frame base $69 (full) vs $20 (corpus).
 *
 * NEXT: trace MOSZeroPageAlloc's decision for truncstair_gate_crc's static frame
 * in the full-ROM link; determine why $69 is chosen and what it aliases. Fix in
 * vendor/llvm-mos on a throwaway worktree, rebuild toolchain, regen 0002,
 * queue upstream. Add this as a regression micro-test.
 */
#include <stdint.h>
#define TS_STEP 0.375f
#define TS_GATE_N 48u
volatile uint16_t corpus_result;
int main(void) {
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)TS_GATE_N; i++) {
        int16_t x_int = (int16_t)((int16_t)i - (int16_t)(TS_GATE_N / 2u));
        float x_f = (float)x_int * TS_STEP;
        int16_t q = (int16_t)x_f;
        float qf = (float)q;
        float diff = x_f - qf;
        int16_t d16 = (int16_t)(diff * 16.0f);
        h = (uint16_t)((uint16_t)(h << 1) | (uint16_t)((h >> 15) & 1u));
        h = (uint16_t)(h ^ (uint16_t)((uint16_t)((int16_t)q*(int16_t)97) ^ (uint16_t)((int16_t)d16*(int16_t)13)));
    }
    corpus_result = h;   /* frame @ $20: 0x02CA correct; frame @ $69 (full ROM): 0x1EB5 wrong */
    for (;;) {}
}
