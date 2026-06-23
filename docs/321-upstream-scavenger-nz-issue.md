<!-- STATUS (internal; strip before posting): drafted 2026-06-18; fix-directions sharpened 2026-06-19
     (feasibility re-probe — why PHP/PLP isn't a drop-in). Ready to post (user-triggered).
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

## Regression — introduced by

The N/Z-dead assumption traces to [`a367c3bb51d0`](https://github.com/llvm-mos/llvm-mos/commit/a367c3bb51d0)
— *"Replace CMPTerm;BR with a new CmpBr."* (2024-02-06): the assertion's premise comment ("virtual
registers are never inserted into CmpBr instructions") is about the `CmpBr` form that commit introduced,
and the `assertNZDeadAt(...) / "expected N to be free when saving scavenger register"` line blames to it.
The premise held for the patterns of the day but is not general — a 16-bit-accumulator compare/ALU keeps
N (or Z) live across a frame-vreg spill. (Ancestor of current `main`.)

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

The obvious "just `PHP`/`PLP` around the spill" isn't sufficient on its own — two constraints make it
non-trivial:

- **`P` has no GPR spill home.** `STImag8`/`LDImag8` are GPR-only, so the current `Reg == MOS::P`
  fallthrough is structurally illegal — `P` can only be saved on the hard stack.
- **`PHP`/`PLP` can't bracket `P` across an *unbalanced* push/pull range.** `saveScavengerRegister`
  takes the hard-stack path only when `pushPullBalanced(I, UseMI)` holds, and the scavenge that trips
  this bug lands inside an *unbalanced* range (a frame spill/reload run with net pushes between `I` and
  `UseMI`), so a plain `PLP` at `UseMI` would pop the wrong byte.

So a correct fix likely needs one of:

1. A **flag-preserving restore that tolerates an unbalanced stack** — save `P` at `I`, restore it with a
   *stack-relative* load at `UseMI` (accounting for the intervening net push) rather than a plain `PLP`; or
2. Teaching the scavenger to **pick a spill point where N/Z is dead** (or to spill a register whose
   save/restore sequence doesn't clobber the flags), so `P` never needs preserving here; or
3. At minimum, **replacing the assert with a graceful path** so a flag-live scavenge cannot silently emit
   illegal MIR in a release build.

### Two approaches that do *not* work (so you can skip them)

We tried two minimal fixes; both move the symptom but hit the **same** underlying wall — the scavenger has
to free a flag/carry-class register at this site that `saveScavengerRegister` has no way to spill:

1. **Gate `canSaveScavengerRegister(MOS::P)` on N/Z-dead** (so the scavenger declines `P` here). The illegal
   `STImag8 $p` goes away, but the scavenger then falls through to `saveScavengerRegister`'s `default:` arm
   and hits `report_fatal_error("Scavenger spill for register not yet implemented")` on a **nameless
   flag/carry-class register**.
2. **Mark `LDCImm` rematerializable** (it lowers to `CLC`/`SEC` — reads nothing, writes only C, not N/Z — so
   it is trivially remat-safe, unlike its base-class sibling `LDImm` = `LDA/LDX/LDY #imm` which writes N/Z;
   note `MOSImmediateLoad` sets `isAsCheapAsAMove`/`isMoveImm` but not `isReMaterializable`). This **changes
   the crash signature** (the `STImag8 $p` becomes the same `"not yet implemented"` dead-end) but does **not**
   clear it — the scavenger still needs to free the same unsaveable flag/carry-class register.

So the fix cannot live in the gate or in rematerialization flags. It has to either (a) **implement a real
flag-preserving spill** for that register class in `saveScavengerRegister` (a `P`/flag save that tolerates
an *unbalanced* push/pull range — the hard part, since flags can only move via the stack or a GPR), or
(b) **prevent these `%N.subcarry` flag/carry-class vregs from being frame-spilled at all** in a flag-live
context (a spill-weight / register-class change so they are always rematerialized). Both are core scavenger
/ frame-lowering changes. The observed double-`P` scavenge in the failing block (a `PH $p` flagged "using an
undefined physical register" alongside the `STImag8 $p`) also suggests the reserved `RC17` save slot
collides across two scavenge events in the same block.

(The `LDCImm`-rematerializable change in (2) is arguably a correct latent improvement on its own — it matches
the sibling `LDImm1` flag-load and is remat-safe — but since it does not fix this crash we are not proposing
it here.)

Happy to provide the full delta-debugged repro, the asserts backtrace, the pre-PEI MIR, and the
`-debug-only=reg-scavenging` trace.
