// #321 native s16 load-fold: a multi-use local `t = a16v + b16v` where both
// operands are near-abs globals. The 1b store-fused peephole can't fold a
// multi-use result, so without this optimization the globals are copied byte-wise
// into Imag16 pairs first. With the alu16_absld combiner rule, the globals are
// read directly: rep; lda a16v; clc; adc b16v; sta __rc; sep.
volatile unsigned short a16v = 0x1234;
volatile unsigned short b16v = 0x1111;
volatile unsigned short g16, h16, corpus_result;
int main(void){
  unsigned short t = a16v + b16v;       // 0x2345, both operands global loads
  g16 = t; h16 = t; corpus_result = t;  // multi-use -> store-fuse can't fire
  for(;;){}
}
