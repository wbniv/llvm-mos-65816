/* Host oracle for the #23 SNES L-system Plant demo: prints the differential gate hash (lsystem_gate_crc()
 * from examples/65816/lsystem.h, compiled host-side). dev/lsystem.sh captures this as EXPECT and asserts
 * the on-console corpus_result (bsnes-jg + MAME) matches it bit-for-bit. The rewrite + interpretation are
 * exact byte/integer operations, so no rounding caveats apply — the variables under test are the string
 * libcalls (memcpy/memmove/strlen) and the bracket push/pop stack. */
#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/lsystem.h"

int main(void) {
    printf("lsystem gate_crc = 0x%04X\n", lsystem_gate_crc());
    return 0;
}
