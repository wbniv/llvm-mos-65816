#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/dhmix.h"
int main(void){
  // verify DH property: B^a == A^b for a few pairs
  uint64_t A=dh_modpow(DH_G,123,DH_P), B=dh_modpow(DH_G,456,DH_P);
  printf("A=g^123=%llu B=g^456=%llu  B^123=%llu A^456=%llu (must match)\n",
         (unsigned long long)A,(unsigned long long)B,
         (unsigned long long)dh_modpow(B,123,DH_P),(unsigned long long)dh_modpow(A,456,DH_P));
  printf("dhmix gate_crc = 0x%04X\n", dhmix_gate_crc());
  return 0;
}
