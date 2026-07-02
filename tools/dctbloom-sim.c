#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/dctbloom.h"
int main(void){ printf("dctbloom gate_crc = 0x%04X\n", dctbloom_gate_crc()); return 0; }
