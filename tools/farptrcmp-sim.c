#define HOST 1
#include <stdio.h>
#include "../examples/65816/farptrcmp.h"
int main(void){printf("farptrcmp gate_crc = 0x%04X\n",farptrcmp_run());return 0;}
