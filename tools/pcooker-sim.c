#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/pcooker.h"
int main(void){ printf("pcooker gate_crc = 0x%04X\n", pcooker_gate_crc()); return 0; }
