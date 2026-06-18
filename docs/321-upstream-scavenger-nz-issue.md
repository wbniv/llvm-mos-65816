<!-- STATUS (internal; strip before posting): drafted 2026-06-18, ready to post (user-triggered).
     Upstream issue for the register-scavenger N/Z-liveness assertion. -->

# [MOS] Register scavenger asserts N/Z dead (`saveScavengerRegister`) — violated when a compare/ALU flag is live across a frame-vreg spill

## Summary

`MOSRegisterInfo::saveScavengerRegister` assumes the N/Z processor-status flags are dead at every
register-scavenging point. When a program keeps an N/Z flag live across a point where
`scavengeFrameVirtualRegs` must spill a frame-index virtual register, the assumption is violated and
the backend emits illegal MIR. An asserts build aborts at the precondition; a release build (no
asserts) emits an illegal `STImag8 $p` (a `$p`-into-GPR-slot spill) that `-verify-machineinstrs`
rejects.

## Where

`llvm/lib/Target/MOS/MOSRegisterInfo.cpp`, `saveScavengerRegister`:

```cpp
// Note: NZ cannot be live at this point, since virtual registers are never
// inserted into CmpBr instructions.
assertNZDeadAt(MBB, I);
assertNZDeadAt(MBB, UseMI);
```

The comment's premise ("virtual registers are never inserted into CmpBr instructions") does not
hold in general: a compare/ALU result flag (N or Z) can remain live across a later frame-index
materialization that the scavenger handles. Downstream in the same function, the `Reg == MOS::P`
case with an unbalanced hard-stack range (`pushPullBalanced` false) falls through to
`STImag8 {Save}, {P}` / `LDImag8 {P}, {Save}`, which is illegal because `P` is not a GPR.

## Reproduce

A recursive function holding several 16-bit values live across the self-call (register pressure →
frame-vreg scavenging) together with a 16-bit compare that keeps N/Z live across that point. Crashes
at `-O1`/`-Os`; compiles clean at `-O0`. (Most readily reproduced with 16-bit-accumulator codegen,
which produces longer flag live ranges, but the bug is in the generic scavenger path.)

```c
volatile unsigned short in_u0 = 0xDC13, in_u1 = 0x6128, in_u2 = 0x8E60, in_idx = 0xC204;
volatile short in_s0 = 0x6ADC;
volatile unsigned short out;

__attribute__((noinline)) static unsigned short f0(unsigned short p0, unsigned short p1) {
  if (p0 == 0) return in_u1;
  unsigned short v0 = (unsigned short)((unsigned)in_u1 + p1);
  unsigned short v1 = (unsigned short)((unsigned)in_u0 - p0);
  unsigned short v2 = (unsigned short)((unsigned)in_s0 + 0xB06Cu);
  unsigned short v4 = (unsigned short)((unsigned)in_u2 + 0xB9FDu);
  unsigned short v5 = (unsigned short)((unsigned)in_idx ^ ((unsigned short)((unsigned)in_u2) >= p1));
  unsigned short r = f0((unsigned short)(p0 - 1u), (unsigned short)((short)in_u0 != (short)in_u2));
  return (unsigned short)((((((v0 | r) | v1) + v5) ^ v2) + v4));
}
int main(void) { out = f0(2, 0xCDD5u); for (;;) {} }
```

Asserts build:

```
MOSRegisterInfo.cpp: assertNZDeadAt(...): Assertion
  `!LiveRegs.contains(MOS::N) && "expected N to be free when saving scavenger register"' failed.
  saveScavengerRegister -> RegScavenger::spill -> scavengeRegisterBackwards -> scavengeFrameVirtualRegs
```

Release build:

```
*** Bad machine code: Illegal physical register for instruction ***
- instruction: $rcN = STImag8 $p
$p is not a GPR register.
fatal error: error in backend: Found N machine code errors.
```

## Likely fix directions

- Save/restore N/Z (and `P`) around the scavenger spill (e.g. `PHP`/`PLP`) instead of asserting them
  dead, so `saveScavengerRegister` is correct when a flag is live; and/or
- give the `P` scavenger-spill a valid lowering when the hard-stack push/pull isn't balanced
  (`pushPullBalanced` false) rather than emitting `STImag8 $p`.

Happy to provide the full delta-debugged repro and asserts backtrace.
