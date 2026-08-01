// #321 native s16 equality-as-value through an INDIRECT operand (`*p == c`).
// Driven by `dev/run.sh a16eqvalp`. See docs/plans/2026-06-16-321-native-s16-eq-gated-impl.md.
//
// Gated native EQ: an s16 equality-as-value whose operand is a non-absolute (indirect)
// load now goes NATIVE 16-bit (`rep; lda (zp); cmp; sep; beq/bne` + 0/1 materialize)
// instead of loading the value 16-bit then unmerging it back into bytes for an 8-bit
// cpx/cmp chain (−4 B on `*p == c`; MOSLegalizerInfo::legalizeICmp gate). Register/
// global/computed operands deliberately stay 8-bit (no regression) — see the plan.
//
// pp is a *volatile pointer* so each `*pp` is a genuine indirect (runtime-pointer) load,
// not constant-folded to an absolute access.
//
// e0 = (*pp == c)  0x1234 == 0x1234 -> 1
// e1 = (*pp == c)  0x00FF == 0x1234 -> 0
// e2 = (*pp != c)  0x00FF != 0x1234 -> 1   (!= as a value)
// corpus_result = e0 | (e1<<4) | (e2<<8) = 1 | 0 | 0x100 = 0x0101  (host==default==+mos-a16)
volatile unsigned short v0 = 0x1234, v1 = 0x00FF;
volatile unsigned short c = 0x1234;
unsigned short *volatile pp;
volatile unsigned short corpus_result;

int main(void) {
  pp = (unsigned short *)&v0;
  unsigned short e0 = (unsigned short)(*pp == c);
  pp = (unsigned short *)&v1;
  unsigned short e1 = (unsigned short)(*pp == c);
  pp = (unsigned short *)&v1;
  unsigned short e2 = (unsigned short)(*pp != c);
  corpus_result =
      (unsigned short)((unsigned)e0 | ((unsigned)e1 << 4) | ((unsigned)e2 << 8));
  for (;;) __asm__ volatile("wai");
}
