#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/plyoracle.h"
int main(void){ printf("plyoracle gate_crc = 0x%04X\n", plyoracle_gate_crc()); return 0; }
