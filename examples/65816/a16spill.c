// #321 +mos-a16 REGRESSION TEST (was Tier-1 fuzzer finding F3; FIXED 2026-06-16).
// Delta-reduced from tools/a16_fuzz.py seed 1. Driven by `dev/run.sh a16spill`.
// See docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md.
//
// The bug: a 16-bit-accumulator (Ac16 = A16) value forced live across a function
// call must be SPILLED across it. The spill path in MOSInstrInfo::loadStoreReg-
// StackSlot only special-cased Imag16 and let Ac16 fall through to a single-byte
// path that did `GPR = COPY A16` — a COPY between the accumulator and an 8-bit reg,
// which copyPhysRegImpl lowers (its Anyi1 branch) to an invalid `SelectImm $a16`:
//
//   *** Bad machine code: Illegal physical register for instruction ***
//   - instruction: $x = SelectImm $a16, -1, 0
//   $a16 is not a Flag register.
//   fatal error: error in backend: Found 2 machine code errors.
//
// -verify-machineinstrs reported it; a normal build SEGFAULTED in link-time codegen.
// (The legalizer compare-as-value path was NOT the cause — post-isel MIR is clean;
// a legalizer-gate fix was tried and reverted. See the plan §Outcome.)
//
// The fix: spill Ac16 with a direct 16-bit LDAbs16/STAbs16 (never a COPY through an
// 8-bit GPR), restoring the native-s16 invariant. Here `arr[in_idx & 7]` keeps a
// 16-bit accumulator value live across f0() under branchy/i1 pressure, so this body
// emits `STAbs16 $a16, %stack.0` / `$a16 = LDAbs16 %stack.0` — exactly the spill the
// fix repairs. A regression re-introduces the `SelectImm $a16` crash below.
//
//   mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
//     -Os -mllvm -verify-machineinstrs -c a16spill.c     # clean now (was: 2 errors)
//   mos-clang --target=mos -mcpu=mosw65816 -Os -c a16spill.c  # default: CLEAN
volatile unsigned short in_u0 = 0x44CB;
volatile unsigned short in_u1 = 0x204F;
volatile unsigned short in_u2 = 0x8298;
volatile short in_s0 = 0x3C5F;
volatile unsigned char in_b0 = 0xFD;
volatile unsigned short in_idx = 0xE623;
volatile unsigned short gu0 = 0xF1CA;
volatile unsigned short gu1 = 0xC25C;
volatile short gs0 = 0x6B7F;
volatile unsigned char gb0 = 0x30;
volatile unsigned short corpus_result;
unsigned short arr[8] = {0xE409, 0x885C, 0x7520, 0x3457, 0xA286, 0xFA9, 0xB6D, 0xD07};

__attribute__((noinline)) static unsigned short f0(unsigned short p0, unsigned short p1) {
  return (unsigned short)((unsigned short)((unsigned short)((short)((unsigned short)0xE032u) >> 8) - (unsigned short)((unsigned)in_u2 - (unsigned short)0xD515u)));
}

int main(void) {
  unsigned short lu0 = 0xF9C8;
  unsigned short lu1 = 0xE83;
  unsigned short lu2 = 0xC795;
  short ls0 = 0xDD93;
  unsigned char lb0 = 0x1;
  unsigned short *p = &arr[(unsigned)in_idx & 7];
  if (((unsigned short)((unsigned short)0xA98Au) <= (unsigned short)((unsigned short)((unsigned)gs0 - (unsigned)f0((unsigned short)((unsigned)lu2), (unsigned short)((unsigned)ls0)))))) {
    *p = (unsigned short)((unsigned short)0x6627u);
    gb0 = (unsigned char)((unsigned)arr[(unsigned)((unsigned)gb0) & 7]);
  } else {
    lb0 = (unsigned char)(((unsigned short)((unsigned)f0((unsigned short)((unsigned)gs0), (unsigned short)((unsigned short)0x1CBCu))) > (unsigned short)((unsigned short)((unsigned)gs0 ^ (unsigned)(*p)))));
  }
  gu1 = (unsigned short)(((unsigned short)((unsigned short)((unsigned)(unsigned short)((unsigned)in_b0) >> 2)) == (unsigned short)((unsigned short)((unsigned short)0x55BEu & (unsigned)in_b0))));
  for (;;) {}
}
