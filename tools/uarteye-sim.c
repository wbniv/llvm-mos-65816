#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/uarteye.h"
int main(void){ printf("uarteye gate_crc = 0x%04X\n", uarteye_gate_crc()); return 0; }
