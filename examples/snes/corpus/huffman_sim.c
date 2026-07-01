/* Corpus slice: huffman HAL-free. host==default==+mos-a16==+mos-xy16 on bsnes-jg, -verify clean.
   Exercises a bit-granular stream reader + pointer-linked Huffman tree descent (decode). */
#include "../../65816/huffman.h"
volatile uint16_t corpus_result;
int main(void){ corpus_result = huffman_gate_crc(); for(;;){} return 0; }
