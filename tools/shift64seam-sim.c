#include <stdio.h>
#include "../examples/65816/shift64seam.h"
int main(void) { printf("shift64seam gate_crc = 0x%04X\n",shift64seam_model()); return 0; }
