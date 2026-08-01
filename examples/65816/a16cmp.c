// #321 native 16-bit unsigned-ordering compares (< <= > >=) feeding branches.
// Each `if` should compile to rep; lda; cmp; sep; bcc/bcs (one 16-bit compare)
// instead of the old multi-block 8-bit cpy/cpx chain. The loval<hival case has
// the LOW byte bigger but the HIGH byte smaller, so a (broken) low-byte-only
// compare would get it wrong — the correct 16-bit result proves all 16 bits compare.
volatile unsigned short a16v  = 0x1234;
volatile unsigned short b16v  = 0x1111;
volatile unsigned short loval = 0x0099;   // low byte 0x99, high byte 0x00
volatile unsigned short hival = 0x0200;   // high byte 0x02 (differs)
volatile unsigned short corpus_result;
int main(void){
  unsigned short r = 0;
  if (a16v  >  b16v)  r += 0x0001;   // 0x1234 > 0x1111  -> true
  if (a16v  <  b16v)  r += 0x0010;   // 0x1234 < 0x1111  -> false
  if (a16v  >= b16v)  r += 0x0100;   // true
  if (b16v  <= a16v)  r += 0x1000;   // true
  if (loval <  hival) r += 0x0002;   // 0x0099 < 0x0200  -> true (high-byte-differs)
  corpus_result = r;                 // 0x0001+0x0100+0x1000+0x0002 = 0x1103
  for (;;) __asm__ volatile("wai");
}
