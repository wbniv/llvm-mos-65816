#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/sobel.h"
int main(void){ printf("sobel gate_crc = 0x%04X\n", sobel_gate_crc()); return 0; }
