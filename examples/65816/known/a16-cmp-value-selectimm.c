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
// This is the compare->stored-bool / select-NZ-lowering follow-up already tracked in
// TODO.md (M2, item c): "equality feeding a stored bool/value still narrows ... needs
// the select/NZ lowering to fold an s16 G_SBC". The fuzzer shows it is not merely
// suboptimal — in branchy contexts it produces invalid MIR. Deferred to that follow-up
// / Tier 2; the fuzzer classifies this signature as XFAIL so the suite stays green.
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
