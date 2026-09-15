/* Corpus slice: bigbyval HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Round 8 Cluster A, the >32-bit BY-VALUE ARGUMENT guard: MOSABIInfo::classifyArgumentType
   (clang/lib/CodeGen/Targets/MOS.cpp:64) sends any aggregate over 32 bits indirect with
   ByVal=false at :71, so the callee gets a pointer to caller-owned storage and C's by-value
   semantics rest entirely on a call-site copy. Every stage here MUTATES its own by-value
   parameter and the driver re-reads its original afterwards — a missing copy corrupts the
   CALLER with no crash, no wrong callee result and no verifier complaint. #91 matcascade
   covered only the RETURN half of the same helper.
   Host oracle: tools/bigbyval-sim.c.
   See docs/plans/2026-09-16-round8-unentered-backend-paths.md. */
#include "../../65816/bigbyval.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bigbyval_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
