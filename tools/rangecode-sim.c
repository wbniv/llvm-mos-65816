#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/rangecode.h"
int main(void){ printf("rangecode gate_crc = 0x%04X\n", rangecode_gate_crc()); return 0; }
