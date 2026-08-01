// #321 xy16 SMOKE TEST — +mos-xy16 (implies +mos-a16) compilation gate.
//
// Exercises the new FeatureIndex16 / +mos-xy16 feature flag: since it implies
// +mos-a16, the same 16-bit-accumulator behaviors apply. The 16-bit store-of-zero
// fusion (MOSInsertREPSEP Increment 1a: two 8-bit stz → rep #$20; stz; sep #$20)
// runs identically under +mos-xy16 as under +mos-a16; the xy16 extension adds the
// X-flag lattice to InsertREPSEP but for M16-only ops (XLow=0) it is a no-op. The
// test proves:
//   1. +mos-xy16 is accepted by the driver (no "unknown feature" error).
//   2. It implies +mos-a16 (the rep #$20 / stz / sep #$20 fusion fires).
//   3. corpus_result == 0x0042 (g16 fully zeroed) on both emulators — the X-flag
//      lattice does not disturb the M-flag REP/SEP placement.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 \
//     -Xclang -target-feature -Xclang +mos-xy16 -Os xy16basic.c
// Driven by dev/run.sh xy16basic. See docs/plans/2026-06-17-321-xy16-index-register-mode.md.

volatile unsigned short g16 = 0xBEEF;
volatile unsigned short corpus_result;

int main(void) {
  g16 = 0;                          // rep #$20; stz g16; sep #$20 (same as +mos-a16)
  corpus_result = g16 + 0x42;       // 0x0000 + 0x42 = 0x0042 iff g16 fully zeroed
  for (;;) __asm__ volatile("wai");
}
