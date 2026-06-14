// #321 Increment 1d-retry step 5: native 16-bit AND/OR/XOR via Imag16 (locals).
// Three bitwise ops on reused locals, none foldable by the combiner peephole.
volatile unsigned short a16v = 0x0FF0;
volatile unsigned short b16v = 0x0F0F;
volatile unsigned short c16v = 0x00FF;
volatile unsigned short g16, h16, i16, corpus_result;
int main(void){
  unsigned short t = a16v & b16v;   // 0x0F00
  unsigned short u = t | c16v;      // 0x0FFF
  unsigned short w = u ^ a16v;      // 0x0FFF ^ 0x0FF0 = 0x000F
  g16 = t; h16 = u; i16 = w;
  corpus_result = w;                // 0x000F
  for(;;){}
}
