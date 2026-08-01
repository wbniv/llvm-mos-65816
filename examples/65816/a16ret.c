// #321 — the A (low) / X (high) RETURN CONVENTION, locked as a tested ABI invariant.
// Driven by `dev/run.sh a16ret`. Plan: docs/plans/2026-06-17-321-ax-return-convention.md.
//
// This is a TEST + DOCS micro-test, NOT a codegen change. The convention is already
// what llvm-mos emits (it is emergent from CC_MOS byte-splitting — there is no separate
// RetCC_MOS), and it is the documented commercial prior art: WDC816CC manual p.21 ("the
// high word of the result … is in the X register, while the low word is in the
// Accumulator") and ORCA/C's `A_X` return class. See
// docs/320-321-65816-c-abi-prior-art.md and the CC decision analysis,
// docs/investigations/65816-calling-convention-decision.md (§"Return values — adopted").
//
// The companion gate in dev/a16ret.sh asserts at the +mos-a16 disassembly that:
//   * the i16 return (add16) leaves the LOW byte in A and the HIGH byte in X at the rts
//     boundary (`ldx <high>; lda <low>; rts`), and
//   * the i8 return (add8) delivers its result in A alone (no X load as a return reg),
// so a later RetCC / A16 / xy16 change can't SILENTLY break the boundary.
//
// NON-GOAL (separate plan): the +mos-a16 return round-trip optimization (keep the value
// in A16 and lift the high byte via XBA->X instead of storing to __rc2:__rc3 then
// reloading the low byte). This plan asserts the *convention*, not the *efficiency* — so
// a deliberate A16-aware return optimization is allowed to update the disasm gate; what
// it may NOT do is change A(low)/X(high) without anyone noticing.
//
// add16(a,b) = 0x12CD + 0x1078 = 0x2345  -> A = 0x45 (low),  X = 0x23 (high)
//   (operands chosen so the 16-bit add carries across the byte boundary: 0xCD+0x78=0x145)
// add8 (p,q) = 0x40   + 0x02   = 0x42    -> A = 0x42        (the project sentinel byte)
// corpus_result = (unsigned short)(add16 + add8) = 0x2345 + 0x42 = 0x2387
//   (a plain sum so EVERY bit of BOTH returns is observable — masking would hide a
//    miscompiled byte. host == default == +mos-a16 on MAME + bsnes-jg.)
//
// Note: the value differential alone cannot catch an A<->X swap (production and
// consumption would swap together and still round-trip) — that is exactly why the disasm
// gate exists; the value test catches miscompiles, the gate catches convention drift.
volatile unsigned short a = 0x12CD, b = 0x1078;
volatile unsigned char  p = 0x40,   q = 0x02;
volatile unsigned short corpus_result;

// noinline so each return is a real rts boundary the disasm gate can inspect (inlining
// would dissolve the convention into main's body).
__attribute__((noinline)) unsigned short add16(unsigned short x, unsigned short y) {
  return (unsigned short)(x + y);
}
__attribute__((noinline)) unsigned char add8(unsigned char x, unsigned char y) {
  return (unsigned char)(x + y);
}

int main(void) {
  unsigned short r16 = add16(a, b);
  unsigned char r8 = add8(p, q);
  corpus_result = (unsigned short)((unsigned)r16 + (unsigned)r8);
  for (;;) __asm__ volatile("wai");
}
