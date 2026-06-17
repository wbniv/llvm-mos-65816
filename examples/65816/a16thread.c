// #321 A16-threading (Phase 1): the redundant Imag16 round-trip between two
// dependent native-s16 ops is eliminated, so the running value threads through
// the accumulator across the whole chain (lda;adc;and;sbc;ora;eor;...;sta) with
// no `sta __rcN; lda __rcN` store-then-reload in between.
//
// Two shapes, both exercised:
//   (1) a dependent HETEROGENEOUS chain whose intermediates are all single-use —
//       every round-trip's store AND reload are removed (fully threaded).
//   (2) a REUSED intermediate (y feeds two ops) — its store must persist for the
//       later reader, but the immediate store-then-reload is still collapsed.
// corpus_result must agree host == default == +mos-a16 on MAME + bsnes-jg.
// See docs/plans/2026-06-17-321-a16-threading.md.
volatile unsigned short a16 = 0x1234;
volatile unsigned short b16 = 0x1111;
volatile unsigned short c16 = 0x0FF0;
volatile unsigned short d16 = 0x0040;
volatile unsigned short e16 = 0x0021;
volatile unsigned short f16 = 0x0001;
volatile unsigned short sink;
volatile unsigned short corpus_result;
int main(void) {
  // (1) single-use dependent chain — fully threaded
  unsigned short t = a16 + b16;   // 0x2345  ADD
  unsigned short u = t & c16;     // 0x0340  AND
  unsigned short v = u - d16;     // 0x0300  SUB
  unsigned short w = v | e16;     // 0x0321  OR
  unsigned short x = w ^ f16;     // 0x0320  XOR
  // (2) reused intermediate — y's store stays, the immediate reload drops
  unsigned short y = a16 + c16;   // 0x2224
  sink = y - d16;                 // 0x21E4  (forces y's store to persist)
  corpus_result = x + y;          // 0x0320 + 0x2224 = 0x2544
  for (;;) {}
}
