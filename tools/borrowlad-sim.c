#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/borrowlad.h"
int main(void){ printf("borrowlad gate_crc = 0x%04X\n", borrowlad_gate_crc()); return 0; }
