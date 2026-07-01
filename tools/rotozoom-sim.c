#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/rotozoom.h"
int main(void){ printf("rotozoom gate_crc = 0x%04X\n", rotozoom_gate_crc()); return 0; }
