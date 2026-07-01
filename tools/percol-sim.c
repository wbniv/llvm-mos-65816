#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/percol.h"
int main(void){
  // sanity: run to percolation, report
  static Percol p; pc_init(&p,0xC0DEu);
  int bonds=0; while(!pc_percolates(&p) && bonds<2000){ pc_add_bond(&p); bonds++; }
  printf("percolates after ~%d bonds, comps=%u/%u\n", bonds, p.comps, (unsigned)PC_N);
  printf("percol gate_crc = 0x%04X\n", percol_gate_crc());
  return 0;
}
