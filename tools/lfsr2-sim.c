#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/lfsr2.h"
int main(void){ printf("lfsr2 gate_crc = 0x%04X\n", lfsr2_gate_crc()); return 0; }
