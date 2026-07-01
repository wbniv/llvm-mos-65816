#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/cosmzoom.h"
int main(void){ printf("cosmzoom gate_crc = 0x%04X\n", cosm_gate_crc()); return 0; }
