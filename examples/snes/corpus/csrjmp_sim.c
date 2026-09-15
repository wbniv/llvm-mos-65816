/* Corpus slice: csrjmp HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 6 Cluster G, the CSR-RESTORE-OFFSET guard for the 65816-native platforms/snes/setjmp.S
   fix (bug #35): 14 coefficient bytes — the exact width of jmp_buf's csrs[14] (__rc18..__rc31) —
   are loaded into locals before a setjmp, a noinline worker occupies and rewrites every
   callee-saved slot, and its longjmp bypasses the epilogue that would restore them. Only
   longjmp's own csrs[] restore can bring the coefficients back, so an off-by-one in those
   offsets corrupts exactly one of them.
   Host oracle: tools/csrjmp-sim.c (gate CRC 0xADD8).
   See docs/plans/2026-09-15-116-118-setjmp-cluster-g-demos.md. */
#include "../../65816/csrjmp.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = csrjmp_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
