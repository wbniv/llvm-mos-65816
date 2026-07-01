#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/radix.h"
int main(void){ printf("radix gate_crc = 0x%04X\n", radix_gate_crc()); return 0; }
