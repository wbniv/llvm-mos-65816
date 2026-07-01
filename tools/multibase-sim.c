#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/multibase.h"
int main(void){
  // sanity: base conversion round-trips
  uint8_t d[6]; uint8_t n=mb_to_base(12345,10,d,6);
  printf("12345 base10 -> "); for(int i=n-1;i>=0;i--)printf("%d",d[i]); printf(" (n=%d)\n",n);
  n=mb_to_base(255,16,d,6); printf("255 base16 -> "); for(int i=n-1;i>=0;i--)printf("%X",d[i]); printf("\n");
  printf("multibase gate_crc = 0x%04X\n", multibase_gate_crc());
  return 0;
}
