/* Host oracle for the vaprintf differential gate.
 * Build: cc -O2 -I examples/65816 tools/vaprintf-sim.c -o build/vaprintf-sim
 */
#include <stdio.h>
#include "vaprintf.h"

int main(void) {
    /* Print the formatted strings so we can eyeball them */
    char buf[32];
    mini_sprintf(buf, "%u+%u", (unsigned)123u, (unsigned)456u);      printf("1: \"%s\"\n", buf);
    mini_sprintf(buf, "%d/%u", (int)-7, (unsigned)3u);                printf("2: \"%s\"\n", buf);
    mini_sprintf(buf, "%x %x", (unsigned)0xBEEFu, (unsigned)0xCAFEu); printf("3: \"%s\"\n", buf);
    mini_sprintf(buf, "%u %d %x", (unsigned)999u, (int)-1, (unsigned)0xABCDu); printf("4: \"%s\"\n", buf);
    uint16_t h = vaprintf_gate_crc();
    printf("vaprintf gate  4 calls  9 va_arg  hash=0x%04X\n", (unsigned)h);
    return 0;
}
