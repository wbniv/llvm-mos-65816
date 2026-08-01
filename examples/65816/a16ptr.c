// #321 native s16 — native 16-bit indirect load/store (`*p`, `a[i]`).
//
// Under +mos-a16 a 16-bit value loaded/stored through a runtime pointer should be
// ONE native 16-bit indirect op — `rep #$20; lda (zp)` / `sta (zp); sep #$20` —
// instead of two 8-bit indirect ops (lda (zp); lda (zp),y). The pointer math is
// already native; this closes the gap on the value access.
//
//   *p = v;             // native 16-bit indirect store -> slot = 0xABCD
//   corpus_result = *p; // native 16-bit indirect load
//   + 1                 // -> 0xABCE  (proves the full 16 bits round-trip)
//
// `p` is volatile so the deref can't be optimized to a direct `slot` access.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16ptr.c
// See docs/plans/2026-06-15-321-native-16bit-indirect-load-store.md.

volatile unsigned short v = 0xABCD;
unsigned short slot;
unsigned short *volatile p = &slot;
volatile unsigned short corpus_result;

int main(void) {
  *p = v;                 // 16-bit indirect store
  corpus_result = *p + 1; // 16-bit indirect load -> 0xABCE
  for (;;) __asm__ volatile("wai");
}
