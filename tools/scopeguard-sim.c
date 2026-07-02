#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/scopeguard.h"
int main(void){ printf("scopeguard gate_crc = 0x%04X\n", scopeguard_gate_crc()); return 0; }
