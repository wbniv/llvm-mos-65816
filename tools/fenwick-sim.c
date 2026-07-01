#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/fenwick.h"
int main(void){
  // sanity: lowbit + BIT prefix vs reference
  printf("lowbit(12)=%u (expect 4)  lowbit(1)=%u  lowbit(16)=%u\n", fw_lowbit(12), fw_lowbit(1), fw_lowbit(16));
  static Fenwick f; fw_clear(&f);
  for(uint16_t i=1;i<=FW_N;i++) fw_set(&f,i,(int16_t)i);
  printf("prefix(10)=%d (expect 55)  ref=%d\n", fw_prefix(&f,10), fw_prefix_ref(&f,10));
  printf("fenwick gate_crc = 0x%04X\n", fenwick_gate_crc());
  return 0;
}
