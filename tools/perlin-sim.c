#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/perlin.h"
int main(void){
  pn_init();
  printf("fade(0)=%d fade(128)=%d fade(256)=%d (expect 0, 128, 256)\n", (int)pn_fade(0),(int)pn_fade(128),(int)pn_fade(256));
  printf("noise(0,0)=%d noise(128,384)=%d\n", (int)pn_noise(0,0), (int)pn_noise(128,384));
  printf("perlin gate_crc = 0x%04X\n", perlin_gate_crc());
  return 0;
}
