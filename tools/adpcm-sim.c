#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/adpcm.h"
int main(void){ printf("adpcm gate_crc = 0x%04X\n", adpcm_gate_crc()); return 0; }
