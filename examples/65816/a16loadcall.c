// #321 regression (gcc c-torture pr34768 class): a 16-bit abs/indirect load that is
// live across a memory-clobbering call must NOT be folded into the post-call ALU op
// or compare operand. foldableAbsLoad16 / foldableIndirLoad16 fold a single-use
// same-BB load into `adc abs` / `cmp abs` / `cmp (zp)`; folding re-reads the memory
// at the USER's location, so if a call writes that memory in between, the fold reads
// the mutated value -> miscompile. The fix bails when any store/call sits between the
// load and the user.
//
// Shape: tmp = g; clobber_writes_g(); use(tmp, g). If g's load (for tmp) is wrongly
// folded into the post-call use, tmp becomes the post-call g -> wrong result.
// Covers: abs global (foldableAbsLoad16, `adc abs`), pointer/(zp) (foldableIndirLoad16,
// `cmp (zp)`), and an across-call compare (CMPAbs16). The 0x1111+0xEEEF=0x0000 pair
// proves all 16 bits. Differential: host == default == +mos-a16 == +mos-xy16, both
// emulators; -verify-machineinstrs clean. (default has no 16-bit fold, so it is the
// trusted reference the a16 build must match.)
// See docs/plans/2026-06-20-321-abs-load-fold-across-call-miscompile.md.
unsigned short g;
unsigned short *pg = &g;
volatile unsigned short corpus_result;

__attribute__((noinline)) void clobber(void) { g = (unsigned short)(0u - g); }

// abs-load operand folded into `adc abs` (foldableAbsLoad16)
__attribute__((noinline)) unsigned short viaabs(void) {
  unsigned short tmp = g;                       // load g (abs) BEFORE the call
  clobber();                                    // g = -g
  return (unsigned short)((unsigned)tmp + g);   // tmp + (-g); mis-fold -> (-g)+(-g)
}

// indirect (zp) load operand (foldableIndirLoad16)
__attribute__((noinline)) unsigned short viaptr(void) {
  unsigned short tmp = *pg;                      // load (zp) BEFORE the call
  clobber();
  return (unsigned short)((unsigned)tmp + *pg);
}

// compare operand across the call (CMPAbs16 fold)
__attribute__((noinline)) unsigned short viacmp(void) {
  unsigned short tmp = g;                        // load g BEFORE the call
  clobber();                                     // g = -g (now large unsigned)
  return (unsigned short)(tmp < g);             // tmp < (-g); mis-fold compares (-g)<(-g)=0
}

int main(void) {
  unsigned short r = 0;
  g = 0x1111;
  r = (unsigned short)((unsigned)r + viaabs());   // 0x1111 + 0xEEEF = 0x0000
  g = 0x1234;
  r = (unsigned short)((unsigned)r + viaptr());   // 0x1234 + 0xEDCC = 0x0000
  g = 0x0005;
  if (viacmp()) r += 0x0100;                       // 5 < 0xFFFB (unsigned) -> 1
  g = 0x4321;
  r = (unsigned short)((unsigned)r + viaabs());   // 0x4321 + 0xBCDF = 0x0000
  corpus_result = r;                               // expected 0x0100
  for (;;) __asm__ volatile("wai");
}
