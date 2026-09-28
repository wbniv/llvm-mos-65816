#include <stdio.h>
#include "../examples/65816/sretrec.h"
int main(void) { printf("sretrec gate_crc = 0x%04X\n", sretrec_gate_crc()); return 0; }
