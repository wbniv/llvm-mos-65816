#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/ulam.h"
int main(void) { printf("ulam gate_crc = 0x%04X\n", ulam_gate_crc()); return 0; }
