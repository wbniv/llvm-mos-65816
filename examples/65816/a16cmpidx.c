// #321 native 16-bit RHS-*indexed* unsigned-ordering compares: `lim < arr[k]`.
// An array/pointer element `arr[k]` legalizes (via a computed pointer) to a 16-bit
// indirect load `lda (zp)` (G_LOAD16_INDIR). When it is the RHS of a single-use
// unsigned-ordering compare, selectSbc16 folds it into `cmp (zp)` (CMPIndir16) under
// one rep/sep bracket — instead of staging the value through an Imag16 temp
// (`lda (zp); sta __rc; lda lim; cmp __rc`). The array is non-volatile (so the load
// is a foldable single use) and the index is volatile (so it can't be constant-folded
// -> a real runtime `arr[k]`). `lim < arr[k]` keeps arr[k] on the RHS (the fold);
// `lim > arr[k]` swaps it to the LHS (the already-optimal `lda (zp); cmp lim`). The
// 0x0099-vs-0x0200 pair proves all 16 bits compare (a low-byte-only compare gets it
// wrong). corpus_result == 0x1111 on BOTH MAME and bsnes-jg.
unsigned short arr[7] = { 0x1234, 0x1111, 0x0099, 0x0200, 0xFFFF, 0x8000, 0x0001 };
unsigned short *parr = arr;
volatile unsigned char k;
volatile unsigned short lim;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short r = 0;
  k = 0; lim = 0x1000; if (lim <  arr[k])  r += 0x0001; // 0x1000 < 0x1234 -> T (+0x0001)
  k = 1; lim = 0x2000; if (lim <  arr[k])  r += 0x0002; // 0x2000 < 0x1111 -> F
  k = 2; lim = 0x0200; if (lim <  arr[k])  r += 0x0004; // 0x0200 < 0x0099 -> F (high byte)
  k = 3; lim = 0x0099; if (lim <  parr[k]) r += 0x0100; // 0x0099 < 0x0200 -> T (high-byte-differs, +0x0100)
  k = 4; lim = 0x8000; if (lim >  arr[k])  r += 0x0008; // 0x8000 > 0xFFFF -> F (arr[k] swaps to LHS)
  k = 5; lim = 0xFFFF; if (lim >  arr[k])  r += 0x1000; // 0xFFFF > 0x8000 -> T (LHS-indexed, +0x1000)
  k = 6; lim = 0x0000; if (lim <  arr[k])  r += 0x0010; // 0x0000 < 0x0001 -> T (+0x0010)
  corpus_result = r;   // 0x0001+0x0100+0x1000+0x0010 = 0x1111
  for (;;) {}
}
