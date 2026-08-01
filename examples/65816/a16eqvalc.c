// #321 native s16 equality-as-value v2 — COMPUTED / Imag16-resident operands.
// Driven by `dev/run.sh a16eqvalc`. See
// docs/plans/2026-06-17-321-native-s16-eq-v2-computed-imag16-lhs.md.
//
// An s16 equality-as-value whose operands are COMPUTED (a native-s16 ALU result already
// resident in Imag16) — or one operand a constant — now goes NATIVE 16-bit:
// `(a+b) == (c+d)` -> `rep; lda imag; cmp imag; sep; beq/bne` + 0/1 (CmpBrImag16), and
// `(a+b) == 0x1234` -> `rep; lda imag; cmp #imm; sep; ...` (CmpBrImm16). Previously these
// narrowed to the 8-bit cpx/cmp two-byte chain even though both operands were already in
// Imag16 (measured -3 B / -2 B). A REGISTER/param operand deliberately stays 8-bit (the
// native form would spill it to Imag16 — the +8 B regression the spike measured).
//
// a,b,c,d are volatile globals so each is a genuine load; (a+b)/(c+d) are computed s16
// values (G_ADD) that the native ALU produces into Imag16.
//
// ab=(a+b)=0x1234, cd=(c+d)=0x1234, ca=(c+a)=0x2100 — all computed (G_ADD of loads).
// e0 = (ab == cd)      0x1234 == 0x1234 -> 1   (computed == computed)
// e1 = (ab == ca)      0x1234 == 0x2100 -> 0
// e2 = (ab != ca)      0x1234 != 0x2100 -> 1   (!= as a value)
// e3 = (ab == 0x1234)  0x1234 == 0x1234 -> 1   (computed == const)
// corpus_result = e0 | (e1<<4) | (e2<<8) | (e3<<12) = 1 | 0 | 0x100 | 0x1000 = 0x1101
volatile unsigned short a = 0x1000, b = 0x0234, c = 0x1100, d = 0x0134;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short ab = (unsigned short)(a + b);
  unsigned short cd = (unsigned short)(c + d);
  unsigned short ca = (unsigned short)(c + a);
  unsigned short e0 = (unsigned short)(ab == cd);
  unsigned short e1 = (unsigned short)(ab == ca);
  unsigned short e2 = (unsigned short)(ab != ca);
  unsigned short e3 = (unsigned short)(ab == 0x1234);
  corpus_result = (unsigned short)((unsigned)e0 | ((unsigned)e1 << 4) |
                                   ((unsigned)e2 << 8) | ((unsigned)e3 << 12));
  for (;;) __asm__ volatile("wai");
}
