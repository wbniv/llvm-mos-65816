// #321 +mos-a16 REGRESSION TEST — soft-stack 16-bit-accumulator spill (FIXED 2026-06-16).
// Companion to examples/65816/a16spill.c, which covers the STATIC-stack spill.
// Driven by `dev/run.sh a16spillr`. See docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md.
//
// The bug: a 16-bit-accumulator (Ac16 = A16) value forced live across a call in a
// REENTRANT function gets spilled to the SOFT stack. MOSRegisterInfo::expandLDSTStk
// (which lowers the STStk/LDStk soft-stack spill pseudos) only special-cased Imag16,
// so an Ac16 value fell through to a generic byte path that tried `COPY A16 -> 8-bit
// GPR` — invalid (A16's high byte B is not byte-addressable without XBA), crashing as
// "Scavenger spill for register not yet implemented" / `SelectImm $a16`. The fix
// spills Ac16 with a single 16-bit INDIRECT load/store (LDAIndir16/STAIndir16) through
// a slot pointer formed in the spill's reserved scratch — the indirect analog of the
// static-stack STAbs16/LDAbs16 fix — never a COPY through an 8-bit reg.
//
// `work` is RECURSIVE, which forces the soft stack (MOSNonReentrant only marks
// non-recursive functions `nonreentrant` -> static stack). The pointer `p = &arr[..]`
// (a 16-bit index in A16) is kept live across the recursive call under a branch, so a
// 16-bit accumulator value must be spilled across the call. The differential gate
// (host == default == +mos-a16 on both emulators) proves the spilled value is correct.
//
//   mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
//     -Os -mllvm -verify-machineinstrs -c a16spillr.c     # clean now (was: backend crash)
volatile unsigned short in_idx = 0xE623;
volatile unsigned short gs0 = 0x6B7F;
volatile unsigned char gb0 = 0x30;
volatile unsigned short corpus_result;
unsigned short arr[8] = {0xE409, 0x885C, 0x7520, 0x3457, 0xA286, 0x0FA9, 0x0B6D, 0x0D07};

__attribute__((noinline)) static unsigned short work(unsigned short n) {
  if (n == 0)
    return (unsigned short)((unsigned)gs0);
  unsigned short *p = &arr[(unsigned)in_idx & 7];
  unsigned short t;
  if ((unsigned short)0xA98Au <=
      (unsigned short)((unsigned)gs0 - (unsigned)work((unsigned short)((unsigned)n - 1u)))) {
    *p = (unsigned short)0x6627u;
    t = (unsigned short)((unsigned)arr[(unsigned)gb0 & 7]);
  } else {
    t = (unsigned short)((unsigned)work((unsigned short)((unsigned)n - 1u)) >
                         (unsigned short)((unsigned)gs0 ^ (unsigned)(*p)));
  }
  return (unsigned short)((unsigned)(*p) + (unsigned)t);
}

int main(void) {
  corpus_result = work(3);
  for (;;) __asm__ volatile("wai");
}
