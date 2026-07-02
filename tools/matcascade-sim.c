#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/matcascade.h"
int main(void){ printf("matcascade gate_crc = 0x%04X\n", matcascade_gate_crc()); return 0; }
