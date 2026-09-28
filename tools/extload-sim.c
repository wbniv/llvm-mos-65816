#include <stdio.h>
#include "../examples/65816/extload.h"
int main(void) { printf("extload gate_crc = 0x%04X\n", extload_gate_crc()); return 0; }
