/* Host oracle for the #29a SNES Bytecode-VM Turtle demo: prints the differential gate hash
 * (vm_gate_crc() from examples/65816/turtle_vm.h, compiled host-side). dev/turtle-vm.sh captures this as
 * EXPECT and asserts the on-console corpus_result (bsnes-jg + MAME) matches it bit-for-bit. The VM is
 * exact integer fixed-point, so no rounding caveats apply — the variables under test are the jump-table
 * switch dispatch and the function-pointer opcode table the interpreter runs on. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/turtle_vm.h"

int main(void) {
    printf("turtle-vm gate_crc = 0x%04X\n", vm_gate_crc());
    return 0;
}
