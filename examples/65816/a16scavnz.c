// a16scavnz.c — deterministic repro for the +mos-a16 register-scavenger crash
// ("Bad machine code: $p is not a GPR register" under -verify-machineinstrs; an
// asserts build aborts earlier at MOSRegisterInfo.cpp `assertNZDeadAt`,
// "expected N to be free when saving scavenger register").
//
// Delta-debugged from fuzz seed-306 (one of 8/500: 169/173/196/268/271/272/306/420).
//
// ROOT CAUSE (pristine UPSTREAM llvm-mos, not #321 code; confirmed via an asserts
// build — see docs/investigations/65816-a16-scavenger-nz-liveness.md):
// `MOSRegisterInfo::saveScavengerRegister` assumes the N/Z processor-status flags
// are dead at every register-scavenging point ("NZ cannot be live at this point,
// since virtual registers are never inserted into CmpBr instructions"). Under
// +mos-a16 a 16-bit compare/ALU keeps N (or Z) live across a point where
// scavengeFrameVirtualRegs must spill a frame-index virtual register, violating
// the precondition. The Release toolchain (assert compiled out) then emits the
// illegal `STImag8 $p` P-spill, which -verify-machineinstrs rejects.
//
// TRIGGER: a recursive function holding ~5 sixteen-bit values live across the
// self-call (register pressure → frame-vreg scavenging) together with a 16-bit
// compare (v5 / the recursive-call argument) that keeps N/Z live across it.
// DEFAULT 8-bit and +mos-a16 -O0 compile clean; only +mos-a16 at -O1/-Os crashes.
//
// XFAIL'd in tools/a16_fuzz.py (KNOWN_ISSUES "scavenger-p-not-gpr"). When the
// upstream scavenger bug is fixed, drop that entry and make this a positive gate.
volatile unsigned short in_u0 = 0xDC13, in_u1 = 0x6128, in_u2 = 0x8E60, in_idx = 0xC204;
volatile short in_s0 = 0x6ADC;
volatile unsigned short corpus_result;

__attribute__((noinline)) static unsigned short f0(unsigned short p0, unsigned short p1) {
  if (p0 == 0)
    return in_u1;
  unsigned short v0 = (unsigned short)((unsigned)in_u1 + p1);
  unsigned short v1 = (unsigned short)((unsigned)in_u0 - p0);
  unsigned short v2 = (unsigned short)((unsigned)in_s0 + 0xB06Cu);
  unsigned short v4 = (unsigned short)((unsigned)in_u2 + 0xB9FDu);
  unsigned short v5 = (unsigned short)((unsigned)in_idx ^ ((unsigned short)((unsigned)in_u2) >= p1));
  unsigned short r = f0((unsigned short)(p0 - 1u), (unsigned short)((short)in_u0 != (short)in_u2));
  return (unsigned short)((((((v0 | r) | v1) + v5) ^ v2) + v4));
}

int main(void) {
  corpus_result = f0(2, 0xCDD5u);
  for (;;) {
  }
}
