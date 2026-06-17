// #321 native s16 equality-as-value v3 — ABS-OPERAND FOLD for GLOBALS (`g1 == g2`).
// Driven by `dev/run.sh a16eqvalg`. See
// docs/plans/2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md.
//
// An s16 equality-as-value (stored to a bool, not just branched on) whose operands are
// BOTH near-abs GLOBALS now goes NATIVE 16-bit with the operand fold: `g1 == g2` ->
// `rep; lda abs g1; cmp abs g2; sep; beq/bne` + 0/1 materialize. Previously the EQ-as-
// value either fell to the 8-bit cpx/cmp two-byte chain or (blanket-native) round-
// tripped each global through an Imag16 pair (`lda abs; sta tmp` x2) — the +4 B
// regression the v1 spike measured in isolation. The fold (mirror of selectSbc16 /
// a16abscmp) reads both globals in place: no `sta zp` round-trip, no `cmp zp` off an
// Imag16 pair, no 8-bit cpx/cpy. Measured a net win in 16-bit-ambient code.
//
// All globals are volatile so each access is a genuine single-use absolute load (not
// constant-folded / CSE'd into one). Each result is stored to its own volatile global
// so the compares stay independent (no expression-chaining that hoists operands away
// from their compare-branch).
//
// r0 = (g0 == g1)   0x1234 == 0x1234 -> 1   (lda abs; cmp abs)
// r1 = (g0 == g2)   0x1234 == 0x00FF -> 0
// r2 = (g0 != g2)   0x1234 != 0x00FF -> 1   (!= as a value)
// corpus_result = r0 | (r1<<4) | (r2<<8) = 1 | 0 | 0x100 = 0x0101 (host==default==+mos-a16)
volatile unsigned short g0 = 0x1234, g1 = 0x1234, g2 = 0x00FF;
volatile unsigned short r0, r1, r2;
volatile unsigned short corpus_result;

int main(void) {
  r0 = (unsigned short)(g0 == g1);
  r1 = (unsigned short)(g0 == g2);
  r2 = (unsigned short)(g0 != g2);
  corpus_result =
      (unsigned short)((unsigned)r0 | ((unsigned)r1 << 4) | ((unsigned)r2 << 8));
  for (;;) {
  }
}
