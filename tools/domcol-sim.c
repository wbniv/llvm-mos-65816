#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/domcol.h"
int main(void){
  // count how many cells hit each colour across the gate sweep (confirm poles fire)
  uint32_t cnt[4]={0,0,0,0};
  for(uint16_t i=0;i<GATE_N;i++){
    float cr=((int16_t)(i&15)-8)*0.125f, ci=((int16_t)((i>>2)&15)-8)*0.125f;
    for(uint8_t gy=0;gy<16;gy++)for(uint8_t gx=0;gx<16;gx++) cnt[domcol_cell(gx,gy,cr,ci)&3]++;
  }
  printf("colour histogram: bg=%u phase=%u halo=%u pole=%u\n",cnt[0],cnt[1],cnt[2],cnt[3]);
  printf("domcol gate_crc = 0x%04X\n", domcol_gate_crc());
  return 0;
}
