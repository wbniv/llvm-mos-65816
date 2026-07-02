#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/bitweave.h"
int main(void){ printf("bitweave gate_crc = 0x%04X\n", bitweave_gate_crc()); return 0; }
