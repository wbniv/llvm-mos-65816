#include <stdio.h>
#include "../examples/65816/bitboard64.h"

int main(void) {
    printf("bitboard64 gate_crc = 0x%04X\n", bitboard64_model());
    return 0;
}
