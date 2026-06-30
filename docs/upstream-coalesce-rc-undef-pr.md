# [MOS] Don't coalesce a call-clobbered imaginary-register value into a pair across the clobber (verifier: undefined physical register)

## Summary

On the 65816 (`+mos-a16`/`+mos-xy16`) under register pressure, the register
coalescer can fold a value read **straight out of a call-clobbered imaginary
register** `$rcN` (`vreg = COPY $rcN`) into an **`Imag16` pair** (via a
sub-register copy) that **outlives the call**. `$rcN` are the calling
convention's imaginary (zero-page) argument/return scratch — a libcall passes
*and* returns values in them and clobbers them via its regmask. Coalescing pulls
the `COPY $rcN` definition into the pair, so the pair inherits the physical-`$rcN`
allocation hint; the allocator then re-binds the pair to `$rcN` **across the
clobber**, leaving a use of `$rcN` with **no reaching definition** on that path:

```
*** Bad machine code: Using an undefined physical register ***
- function:    newton_step
- instruction: renamable $x = COPY killed renamable $rc3
```

The value happens to survive in `$rcN` at runtime (nothing reuses it in the
gap), so the emitted code runs correctly — but the IR is ill-formed and a latent
miscompile hazard, which is exactly why `-verify-machineinstrs` rejects it.

## Reproduction

A high-register-pressure `+mos-a16` function with sequential `__mulsi3` libcalls
whose results stay live into a later block (e.g. a Newton's-method complex-divide
step), compiled `-mcpu=mosw65816 -Os -mllvm -verify-machineinstrs`, aborts the
verifier with the message above. `-mllvm -join-liveintervals=false` (disable the
coalescer) makes it verify clean, localizing it to the coalescer; an asserts
`-debug-only=regalloc` join trace pins the exact join: a `vreg = COPY $rc3` read
of the first libcall's result is folded into an `Imag16` pair at `%pair.sublo`,
rewriting the def to `%pair.sublo = COPY $rc3`, and the pair is then allocated to
`$rc2:$rc3` across a second `__mulsi3` that clobbers `$rc3`.

## Fix

`MOSRegisterInfo::shouldCoalesce` — refuse the join when it would fold a value
into an **`Imag16`** register (a sub-register copy building a pair) and one of the
copy operands is a virtual register whose **unique definition is `vreg = COPY
$rcN`** (a physical `Imag8`) **and** that vreg is **live across a call that
clobbers `$rcN`** (`LiveIntervals::checkRegMaskInterference`). Keeping the COPY
gives the value its own vreg the allocator can spill/relocate across the call.

This mirrors the existing rotate/inc-dec guards in the same function. It is
**correctness-safe by construction** (refusing a coalesce only ever costs a copy)
and tightly gated: across a 34-program 65816 differential corpus it changes only
**4** programs (all stay `-verify` clean and differential-identical), the other
**30** are byte-identical.

```cpp
if (NewRC == &MOS::Imag16RegClass && (DstSubReg || SubReg)) {
  if (copiedFromClobberedPhysImag(MI->getOperand(0).getReg(), MRI, LIS) ||
      copiedFromClobberedPhysImag(MI->getOperand(1).getReg(), MRI, LIS))
    return false;
}
```

where `copiedFromClobberedPhysImag(Reg)` is true iff `Reg`'s unique def is
`Reg = COPY $rcN` with `$rcN` a physical `Imag8`, and
`checkRegMaskInterference(LIS.getInterval(Reg))` reports `$rcN` clobbered.

## Test

`llvm/test/CodeGen/MOS/coalesce-rc-undef.mir` — a `-run-pass=register-coalescer`
test: a value `COPY $rc3` held live across a `JSR … mos_csr` (clobbering `$rc3`)
and folded into an `Imag16` pair must **not** be coalesced (the `COPY` survives).
It fails before the fix (the `COPY` is removed and the def becomes
`%pair.sublo = COPY $rc3`) and passes after.

## Validation (downstream llvm-mos-65816 fork)

- The `newton_step` repro and the lifted minimal repro `rcundef.c` verify clean
  at `-O0/-O1/-Os` (a16 + xy16); the Newton SNES demo's value is unchanged
  (`0x4D8B`, MAME + bsnes-jg), the ROM only re-allocates a few registers.
- Differential corpus 32/33 (the one miss is an unrelated build-artifact naming
  quirk), 4/34 programs change bytes (all verify clean + differential green), 30
  byte-identical. Correctness-safe by construction.

## Scope note — a second, distinct cause this does NOT fix

A *different* shape produces the same verifier message: the register **allocator**
binds a **pure-virtual** `Imag16` value — one with **no `$rcN` copy at all** in its
def/use chain — to a call-clobbered `$rc` pair it is live across (no copy-hint for
`shouldCoalesce` to key on). That is an RA-interference-level issue (greedy
RA/`LiveRegMatrix` not treating the regmask clobber of the imaginary pair as
interference) and is out of scope for this coalescer guard.

## The patch

```diff
--- a/llvm/lib/Target/MOS/MOSRegisterInfo.cpp
+++ b/llvm/lib/Target/MOS/MOSRegisterInfo.cpp
+// True if the virtual register Reg's unique definition is a COPY directly out of a
+// physical imaginary register ($rcN) — `Reg = COPY $rcN` — and Reg is live across a
+// call that clobbers that same $rcN. (See full comment in tree.)
+static bool copiedFromClobberedPhysImag(Register Reg,
+                                        const MachineRegisterInfo &MRI,
+                                        LiveIntervals &LIS) {
+  if (!Reg.isVirtual() || !LIS.hasInterval(Reg))
+    return false;
+  const MachineInstr *Def = MRI.getUniqueVRegDef(Reg);
+  if (!Def || !Def->isCopy())
+    return false;
+  Register Src = Def->getOperand(1).getReg();
+  if (!Src.isPhysical() || !MOS::Imag8RegClass.contains(Src))
+    return false;
+  BitVector Usable;
+  return LIS.checkRegMaskInterference(LIS.getInterval(Reg), Usable) &&
+         !Usable.test(Src.id());
+}
+
 bool MOSRegisterInfo::shouldCoalesce(
     MachineInstr *MI, const TargetRegisterClass *SrcRC, unsigned SubReg,
     const TargetRegisterClass *DstRC, unsigned DstSubReg,
     const TargetRegisterClass *NewRC, LiveIntervals &LIS) const {
   const auto &MRI = MI->getMF()->getRegInfo();
+
+  // Don't fold a value read straight out of a call-clobbered imaginary register
+  // ($rcN, via `vreg = COPY $rcN`) into an Imag16 pair (a sub-register copy) when
+  // that value outlives the clobbering call — the pair inherits the $rcN hint and
+  // the allocator re-binds it to $rcN across the clobber (verifier: "Using an
+  // undefined physical register"). Refusing keeps the COPY. Correctness-safe.
+  if (NewRC == &MOS::Imag16RegClass && (DstSubReg || SubReg)) {
+    if (copiedFromClobberedPhysImag(MI->getOperand(0).getReg(), MRI, LIS) ||
+        copiedFromClobberedPhysImag(MI->getOperand(1).getReg(), MRI, LIS))
+      return false;
+  }
```

(Requires `#include "llvm/ADT/BitVector.h"` and
`#include "llvm/CodeGen/LiveIntervals.h"`.)

The complete, self-contained change (the `copiedFromClobberedPhysImag` helper, the
`shouldCoalesce` guard, the two includes, and the lit test) is carried as
**`patches/llvm-mos/0015-321-coalesce-rc-undef.patch`** — generated against and
verified to apply cleanly to pristine upstream `c798c3141` (`git apply --check`),
exactly the `0010-coalesce-rotate-ac` model. (It also lands in the comprehensive
fork patch `0002` for the live in-fork build, as every backend change does.)

## Posting (user-triggered)

Mint a branch off pristine `c798c3141`, apply `0015`, push, and open the PR:

```sh
# in a fresh pristine llvm-mos clone at c798c3141:
git checkout -b mos-coalesce-rc-undef c798c3141
git apply /path/to/patches/llvm-mos/0015-321-coalesce-rc-undef.patch
git add -A && git commit -m "[MOS] Don't coalesce a call-clobbered imaginary-register value into a pair across the clobber"
git push wbniv mos-coalesce-rc-undef
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-coalesce-rc-undef \
  --title "[MOS] Don't coalesce a call-clobbered imaginary-register value into a pair across the clobber" \
  --body-file docs/upstream-coalesce-rc-undef-pr.md   # strip this status block first
```
