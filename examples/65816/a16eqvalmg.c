// #321 native s16 equality-as-value task7 — COMPUTED vs GLOBAL (mixed fold).
// Driven by `dev/run.sh a16eqvalmg`.
// See docs/plans/2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md.
//
// One operand is COMPUTED (a native-s16 ALU result already resident in Imag16, e.g. `a+b`)
// and the other is a near-abs GLOBAL. Now selects `rep; lda zp_computed; cmp abs_global; sep`
// (CmpBrImagAbs16: LDAImag16 + CMPAbs16) instead of materializing the global into an Imag16
// pair first. Both operand orderings are tested: the legalizer swap ensures the computed value
// always arrives on LHS for selectBrCondImm, so `global == computed` canonicalizes to the same
// fold as `computed == global`.
//
// ab = a + b = 0x1000 + 0x0234 = 0x1234  (computed; volatile loads prevent constant folding)
// g  = 0x1234  (volatile global, matches ab)
// h  = 0x5678  (volatile global, does NOT match ab)
//
// e0 = (ab == g)  -> 1   computed LHS, global RHS, match
// e1 = (g  == ab) -> 1   global LHS, computed RHS -- tests legalizer swap to canonical form
// e2 = (ab != h)  -> 1   mismatch, != form (same fold, flag_val inverted)
// e3 = (h  == ab) -> 0   global LHS, mismatch -- guards false positive in the reverse form
// corpus_result = e0 | (e1<<4) | (e2<<8) | (e3<<12) = 1 | 0x10 | 0x100 | 0 = 0x0111
volatile unsigned short a = 0x1000, b = 0x0234;
volatile unsigned short g = 0x1234, h = 0x5678;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short ab = (unsigned short)(a + b);
  unsigned short e0 = (unsigned short)(ab == g);
  unsigned short e1 = (unsigned short)(g == ab);
  unsigned short e2 = (unsigned short)(ab != h);
  unsigned short e3 = (unsigned short)(h == ab);
  corpus_result = (unsigned short)((unsigned)e0 | ((unsigned)e1 << 4) |
                                   ((unsigned)e2 << 8) | ((unsigned)e3 << 12));
  for (;;) __asm__ volatile("wai");
}
