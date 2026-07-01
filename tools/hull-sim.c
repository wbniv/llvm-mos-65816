#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/hull.h"
int main(void){
  // simple square + interior point -> hull should be 4
  HlPt p[5]={{0,0},{10,0},{10,10},{0,10},{5,5}}; uint8_t hull[5];
  uint8_t hc=hl_giftwrap(p,5,hull);
  printf("square+center hull count=%u (expect 4)\n", hc);
  printf("hull gate_crc = 0x%04X\n", hull_gate_crc());
  return 0;
}
