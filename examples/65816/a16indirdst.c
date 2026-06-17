// #321 task7 spike — volatile-pointer indir-dst copy fold (item 5). Driven by host compile only.
// See docs/plans/2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md §5.
//
// Pattern: `*volatile_ptr_var = g_global` where the ptr-var load is volatile-ordered.
// Today, `shouldFoldMemAccess` sees the ordered ptr-load between the value-load and the store
// and declines to fold — the value round-trips through Imag16 (extra lda zp; sta (zp) becomes
// lda abs; sta imag; lda imag; sta (zp)). Spike: measure the round-trip cost.
//
// volatile unsigned short **p: pointer-to-pointer (volatile ptr load forces the ordering).
// g = 0x1234 (near-abs global value to store).
// After `*p_var = g`: corpus_result should equal g = 0x1234.
volatile unsigned short g_val = 0x1234;
volatile unsigned short dst_mem = 0;
volatile unsigned short *volatile p_var = &dst_mem;
volatile unsigned short corpus_result;

int main(void) {
  *p_var = g_val;          // *volatile_ptr_var = global: the indir-dst pattern
  corpus_result = dst_mem; // read it back
  for (;;) {
  }
}
