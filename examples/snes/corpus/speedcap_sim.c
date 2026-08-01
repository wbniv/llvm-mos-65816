/* Corpus slice: speedcap HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Exercises G_FMINNUM/G_FMAXNUM via __builtin_fminf/__builtin_fmaxf as velocity
   speed governor (fminf(fmaxf(v, -MAX_V), MAX_V)).  Both are .libcallFor S32
   → fminf/fmaxf in the SDK (math.cc:18-19).  First demo to use fminf/fmaxf
   without an immediately adjacent G_FPTOSI saturating-cast. */
#include "../../65816/speedcap.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = speedcap_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
