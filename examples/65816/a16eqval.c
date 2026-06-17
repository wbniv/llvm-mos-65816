// #321 native s16 — equality consumed as a VALUE (`b = (a == c)`), not a branch.
// Driven by `dev/run.sh a16eqval`. History: docs/plans/2026-06-16-321-s16-load-unmerge-bytewise.md
// (byte-wise stopgap), superseded by docs/plans/2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md.
//
// The 2026-06-16 byte-wise stopgap (load the operands byte-wise so equality-as-value
// matched the default build instead of a wasteful 16-bit-load+spill round-trip) is now
// SUPERSEDED for GLOBALS by v3: a,b,c,d are globals, so each `==`/`!=` goes NATIVE 16-bit
// and the abs-fold reads them in place (`rep; lda abs; cmp abs; sep; beq/bne` + 0/1),
// measured smaller than both the round-trip AND the 8-bit chain. (The full-native compare
// the stopgap deferred is exactly what v1/v3 landed.) No round-trip, no 8-bit cpx/cpy.
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
