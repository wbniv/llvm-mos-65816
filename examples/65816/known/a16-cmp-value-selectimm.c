// KNOWN-ISSUE repro — #321 +mos-a16 backend crash (found by the Tier-1 differential
// fuzzer, tools/a16_fuzz.py seed 1; delta-reduced).  Tracked as known-issue id
// "cmp-value-selectimm"; see docs/plans/2026-06-15-321-tier1-broaden-corpus.md §Findings.
//
// Trigger: a 16-bit compare whose boolean (i1) result is consumed as a cross-block
// VALUE (a stored bool / PHI under branchy control flow) rather than feeding a branch
// directly. Under +mos-a16 the i1 is materialized with `SelectImm $a16, -1, 0`
// (or `SelectImm $y, …`) — a GPR where the pseudo requires a Flag (NZ/C) register:
//
//   *** Bad machine code: Illegal physical register for instruction ***
//   - instruction: $x = SelectImm $a16, -1, 0
//   $a16 is not a Flag register.
//   fatal error: error in backend: Found 2 machine code errors.
//
// -verify-machineinstrs reports it; a normal build SEGFAULTS in link-time codegen.
//
// ROOT CAUSE (corrected 2026-06-16 — see docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md
// §Outcome): this is NOT the legalizer compare-as-value path (that lowers cleanly — the
// post-instruction-selection MIR has no SelectImm). It is a REGISTER-ALLOCATOR bug: the
// `SelectImm $a16` first appears after `postrapseudos`, emitted by MOSInstrInfo::copyPhysRegImpl
// (the Anyi1->Anyi1 COPY branch) because an i1 value got entangled with the 16-bit-accumulator
// (ac16) live range during coalescing. Here `arr[in_idx & 7]` keeps a 16-bit accumulator value
// live across the f0() call; under this branchy CFG + i1 compare-result pressure the spill/copy
// of that accumulator routes through the i1->GPR SelectImm, reading $a16 as a flag. This is the
// SAME A16<->8-bit coalescer crash the native-s16 add path avoided "by construction" (ROADMAP
// step 5, Increment 1d), resurfacing via spill copies. It is Tier-2 register-allocator work;
// the fuzzer classifies this signature as XFAIL so the suite stays green until it lands.
// (A legalizer-gate fix — narrowing UGE/EQ-as-value to the 8-bit chain — was tried 2026-06-16
// and reverted: it produces clean SSA but does NOT prevent the post-RA entanglement.)
//
// Reproduce:
//   mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
//     -Os -mllvm -verify-machineinstrs -c a16-cmp-value-selectimm.c     # crashes
//   mos-clang --target=mos -mcpu=mosw65816 -Os -c a16-cmp-value-selectimm.c  # default: CLEAN
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
