// #321 task7 spike — `x == 0` as a VALUE (item b). Driven by `dev/run.sh a16eqvalz` (if built).
// See docs/plans/2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md §2.
//
// For a BRANCH, `x == 0` already goes via G_CMPZ (byte-OR, 8-bit). For a VALUE (`b = (x == 0)`):
// native 16-bit path: `rep; lda imag; sep` (sets Z) vs 8-bit path: `lda lo; ora hi` (byte-OR).
// The native form adds rep/sep overhead the 8-bit form avoids; they are expected to be isometric
// or the native form regressive — measure and confirm.
//
// x  = 0x0000 → x==0 → 1
// y  = 0x1234 → y==0 → 0
// e0 = (x == 0) → 1
// e1 = (y == 0) → 0
// corpus_result = e0 | (e1<<4) = 0x0001
volatile unsigned short x = 0x0000, y = 0x1234;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short e0 = (unsigned short)(x == 0);
  unsigned short e1 = (unsigned short)(y == 0);
  corpus_result = (unsigned short)((unsigned)e0 | ((unsigned)e1 << 4));
  for (;;) __asm__ volatile("wai");
}
