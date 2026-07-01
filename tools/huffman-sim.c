#include <stdio.h>
#include <stdint.h>
#include "../examples/65816/huffman.h"
int main(void){
  static uint8_t s[HF_STREAM_BYTES], o[HF_N];
  uint16_t bits=hf_encode(s); hf_decode(s,o,HF_N);
  int bad=0; for(uint16_t p=0;p<HF_N;p++) if(o[p]!=hf_img(p%HF_W,p/HF_W)) bad++;
  printf("encoded %u bits (%u bytes), decode mismatches=%d\n", bits, (bits+7)/8, bad);
  printf("huffman gate_crc = 0x%04X\n", huffman_gate_crc());
  return 0;
}
