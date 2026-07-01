#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "../examples/65816/editdist.h"
int main(void){
  static EditDist e;
  const char *A="KITTEN", *B="SITTING";  // classic: distance 3
  ed_fill(&e,(const uint8_t*)A,6,(const uint8_t*)B,7);
  printf("edit(KITTEN,SITTING)=%u (expect 3)\n", e.dist);
  printf("editdist gate_crc = 0x%04X\n", editdist_gate_crc());
  return 0;
}
