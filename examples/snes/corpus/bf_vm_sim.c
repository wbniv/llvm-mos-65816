/* Corpus slice: bf-vm HAL-free. Differential engine checks it 5 ways:
   host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
   Stresses computed-goto / labels-as-values threaded dispatch (jmp ($ind)). */
#include "../../65816/bf_vm.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = bf_vm_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
