// #321 native s16 — fused indirect 16-bit copy (`g = *p`).
//
// The abs←abs copy (`g = gg`) was already fused (copy16abs combiner). This covers
// the indirect case, fused at selection: a single-use 16-bit load feeding a 16-bit
// store folds the load directly into the accumulator — no Imag16 temp round-trip —
// so `g = *p` is `lda (p); sta g` (under one rep/sep) instead of
// `lda (p); sta tmp; lda tmp; sta g`.
//
// psa is a volatile pointer so the deref isn't folded to a direct access; the loaded
// VALUE (a plain unsigned short) is non-volatile and the store address is absolute,
// so the value-load sits adjacent to the store and the load-fold safety check
// (shouldFoldMemAccess) permits the fusion. da is volatile so reading it back is a
// real reload (not store-forwarded), keeping the copy's load single-use.
// da = *psa = sa = 0x2345; corpus_result = da + 0x1111 = 0x3456.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16copy.c
// See docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md (copy-fusion follow-up).

unsigned short sa = 0x2345;
volatile unsigned short da;
unsigned short *volatile psa = &sa;
volatile unsigned short corpus_result;

int main(void) {
  da = *psa;                    // abs <- indir copy (fused: lda (psa); sta da)
  corpus_result = da + 0x1111;  // 0x2345 + 0x1111 = 0x3456
  for (;;) __asm__ volatile("wai");
}
