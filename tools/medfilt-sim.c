#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/medfilt.h"
int main(void){ printf("medfilt gate_crc = 0x%04X\n", medfilt_gate_crc()); return 0; }
