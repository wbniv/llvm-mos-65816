// #321 native s16 — equality consumed as a VALUE (`b = (a == c)`), not a branch.
// Driven by `dev/run.sh a16eqval`. See docs/plans/2026-06-16-321-s16-load-unmerge-bytewise.md.
//
// Equality-as-value still narrows to the 8-bit cpx chain (the native compare is a
// deferred follow-up — see TODO). But under +mos-a16 the operand LOADS used to be a
// wasteful round-trip: `rep; lda abs -> A16; sta imag16; sep` then read the bytes back
// for the 8-bit compare — strictly worse than the default build, which loads the bytes
// directly. Fixed 2026-06-16 (MOSLegalizerInfo::legalizeLoadStore16): an s16 load whose
// uses are all G_UNMERGE keeps its byte-wise lowering. So the compares below load their
// operands byte-wise (no rep #$20 before the first cmp/cpx) — back to parity with default.
//
// e0 = (a == b)  0x1234==0x1234 -> 1
// e1 = (a == c)  0x1234==0x00FF -> 0
// e2 = (c != d)  0x00FF!=0x1234 -> 1   (!= as a value)
// corpus_result = e0 | (e1<<4) | (e2<<8) = 1 | 0 | 0x100 = 0x0101  (host==default==+mos-a16)
volatile unsigned short a = 0x1234, b = 0x1234, c = 0x00FF, d = 0x1234;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short e0 = (unsigned short)(a == b);
  unsigned short e1 = (unsigned short)(a == c);
  unsigned short e2 = (unsigned short)(c != d);
  corpus_result =
      (unsigned short)((unsigned)e0 | ((unsigned)e1 << 4) | ((unsigned)e2 << 8));
  for (;;) {
  }
}
