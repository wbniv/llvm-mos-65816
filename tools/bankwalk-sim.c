#define HOST 1
#include <stdio.h>
#include "../examples/65816/bankwalk.h"
int main(void){printf("bankwalk gate_crc = 0x%04X\n",bankwalk_run());return 0;}
