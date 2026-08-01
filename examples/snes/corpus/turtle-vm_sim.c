/* Corpus slice: bytecode-VM turtle dispatch gate, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. Shares
 * examples/65816/turtle_vm.h with the renderer (examples/snes/turtle-vm.c) and the host oracle
 * (tools/turtle-vm-sim.c).
 *
 * vm_gate_crc runs the bytecode program through the stack-machine interpreter — whose main switch(op)
 * lowers to a JMP (abs,X) jump table and whose ALU ops dispatch through a function-pointer opcode table
 * (jsr __call_indir) — and folds the turtle path into a CRC16. No pointers leave bank 0 (near fnptrs),
 * so it is a full 5-way test of computed/indirect control flow; the integer math is exact, so host and
 * target must agree bit-for-bit. */
#include "../../65816/turtle_vm.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = vm_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
