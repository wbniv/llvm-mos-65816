#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/crctex.h"

int main(void) {
    /* sanity: standard CRC-32 of "123456789" must be 0xCBF43926 */
    const uint8_t chk[9] = { '1','2','3','4','5','6','7','8','9' };
    printf("crc32(\"123456789\") = 0x%08X\n", crc32_buf(chk, 9));
    printf("crctex gate_crc = 0x%04X\n", crctex_gate_crc());
    return 0;
}
