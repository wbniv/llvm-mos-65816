// #321 native s16 immediate-operand optimization: a multi-use local add of a
// 16-bit immediate. `t` is reused by three stores, so the 1b/1c combiner peephole
// (single store-of-ALU) CANNOT fold it — the add goes native. With the immediate
// fold, the constant becomes `adc #$0345` instead of being materialized into an
// Imag16 pair: clc; rep; lda a; adc #$0345; sta; sep.
volatile unsigned short a16v = 0x1200;
volatile unsigned short g16, h16, corpus_result;
int main(void){
  unsigned short t = a16v + 0x0345;     // -> adc #$0345 ; 0x1200 + 0x0345 = 0x1545
  g16 = t; h16 = t; corpus_result = t;  // multi-use forces the native path
  for(;;){}
}
