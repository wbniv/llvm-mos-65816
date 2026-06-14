// #321 Increment 1d-retry step 5: a GISel-native 16-bit SUBTRACT via Imag16.
// `t` is a multi-use LOCAL so the combiner peephole can't fold it; the s16 sub
// must go native: sec; rep; lda a; sbc b; sta; sep — value resident in Imag16.
volatile unsigned short a16v = 0x1456;
volatile unsigned short b16v = 0x0234;
volatile unsigned short g16, h16, corpus_result;
int main(void){
  unsigned short t = a16v - b16v;   // 0x1456 - 0x0234 = 0x1222
  g16 = t; h16 = t; corpus_result = t;
  for(;;){}
}
