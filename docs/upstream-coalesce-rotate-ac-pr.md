# [MOS] Don't coalesce two rotate-referenced values into the A-only `Ac` class (silent miscompile)

## Summary

On the 65816 (and any MOS subtarget), the register coalescer can merge two
shift/rotate-referenced values together into the **A-only `Ac`** register class.
Because `ASL`/`LSR`/`ROL`/`ROR` can only operate on the accumulator, an `Ac`
value is pinned to `A` for its entire live range. When such a value is also
loop-carried across an inner conditional whose *other* arm needs `A` — the
canonical case is an **inlined CRC16 bit loop**, where the bit-15 test reloads
the pre-rotate byte into `A` while the rotated high byte must survive to the
next iteration — coalescing removes the `COPY` that would let the live value
vacate `A`. The allocator then strands the value in `Y` while the loop
back-edge's `ROL` reads a **stale `A`**, silently miscompiling. `-verify-machineinstrs`
and `-verify-coalescing` are both clean, so nothing catches it.

## Reproduction

A natural CRC16-CCITT fold over an array, compiled `-mcpu=mosw65816 -Os` (default
8-bit accumulator, no `+mos-a16`), under enough register pressure that the
rolling CRC high byte is allocated to `Ac`, computes a **different runtime value**
than the byte-identical unrolled form. The divergence is the high byte of the
CRC accumulator falling one rotation behind, starting from the first iteration
that takes the no-XOR (skip) path:

```
loop:  sta __rc2      ; save old crc-high for the sign test
       asl __rc29     ; crc-low << 1
       rol            ; A = new crc-high
       tay            ; Y = new crc-high
       lda __rc2      ; A = OLD crc-high  (clobbers A for the bit-15 test)
       bpl .skip      ; if bit 15 == 0, skip the ^0x1021
       ...xor path ends: tay ; (Y = updated crc-high)...
.skip:               ; <-- no `tya`: A holds the STALE old crc-high
       dex
       bne loop       ; next `rol` rotates the stale A
```

`-mllvm -join-liveintervals=false` (disable coalescing) makes it correct, which
localizes it to the coalescer; bisecting the joins shows it is the coalescing of
two rotate-referenced values into `Ac`.

## Fix

`MOSRegisterInfo::shouldCoalesce` — refuse the join when the resulting class is
`Ac` and **both** the copy's source and destination are referenced by a
shift/rotate. Keeping the `COPY` lets the value occupy the broader `AImag8`/`AY`
class and spill/transfer across the `A`-clobber as needed. This mirrors the
existing rotate guards in the same function (which forbid coalescing rotate
values *into* `Imag8` memory for performance); this one is a *correctness* guard.

```cpp
if (NewRC == &MOS::AcRegClass &&
    referencedByShiftRotate(MI->getOperand(0).getReg(), MRI) &&
    referencedByShiftRotate(MI->getOperand(1).getReg(), MRI))
  return false;
```

## Test

`llvm/test/CodeGen/MOS/coalesce-rotate-ac.mir` — a `-run-pass=register-coalescer`
test: two `ROL` results connected by a `%x:ac = COPY` must NOT be coalesced. It
fails before the fix (the COPY is removed and the two `ROL`s chain through one
vreg) and passes after.

## Validation (downstream llvm-mos-65816 fork)

- The real miscompile (a Mode-7 zoom demo's CRC fold) now matches the host/unrolled
  reference: the loop form computes `0xF56C` (was `0xE60E`).
- Zero regressions: corpus differential 7/7, c-torture 30/30 (default == a16 ==
  xy16), Csmith 54/60 (0 mismatch / 0 crash / 0 error), `-verify-machineinstrs` clean.
- Code-size impact: a few bytes per affected CRC-style loop (the preserved copy).

## The patch

```diff
--- a/llvm/lib/Target/MOS/MOSRegisterInfo.cpp
+++ b/llvm/lib/Target/MOS/MOSRegisterInfo.cpp
@@ -763,6 +763,21 @@
     const TargetRegisterClass *NewRC, LiveIntervals &LIS) const {
   const auto &MRI = MI->getMF()->getRegInfo();
 
+  // Don't coalesce two shift/rotate-referenced values together into the A-only Ac
+  // class. The accumulator is the only register ASL/LSR/ROL/ROR can operate on, so
+  // an Ac value is pinned to A for its whole live range. When such a value is also
+  // loop-carried across an inner conditional whose other arm needs A (e.g. an
+  // inlined CRC16 bit loop: the bit-test reloads the pre-rotate byte into A, while
+  // the rotated value must survive to the next iteration), pinning it to A-only
+  // leaves the allocator no register to evict it to on the skip path — it strands
+  // the live value in Y while the back-edge rotate reads a stale A, miscompiling
+  // silently (the machine verifier does not catch it). Keeping the copy live lets
+  // the value occupy the broader AImag8/AY class and spill/transfer as needed.
+  if (NewRC == &MOS::AcRegClass &&
+      referencedByShiftRotate(MI->getOperand(0).getReg(), MRI) &&
+      referencedByShiftRotate(MI->getOperand(1).getReg(), MRI))
+    return false;
+
   // Don't coalesce Imag8 and AImag8 registers together when used by shifts or
   // rotates.  This may cause expensive ASL zp's to be used when ASL A would
   // have sufficed. It's better to do arithmetic in A and then copy it out.
```

And the regression test `llvm/test/CodeGen/MOS/coalesce-rotate-ac.mir`:

```mir
# RUN: llc -mtriple=mos -mcpu=mosw65816 -run-pass=register-coalescer %s -o - | FileCheck %s

# A value used by a rotate (ROL) is pinned to the accumulator (the Ac class), the
# only register the rotate can read/write. Coalescing two such values together
# into Ac removes the COPY that lets the live value vacate A when the other arm of
# an enclosing conditional needs A (e.g. an inlined CRC16 bit loop). That strands
# the value and the back-edge rotate reads a stale A -> a silent miscompile. The
# coalescer must keep the COPY (MOSRegisterInfo::shouldCoalesce).
---
name: dont_coalesce_rotate_into_ac
tracksRegLiveness: true
body: |
  bb.0:
    liveins: $a, $c
    ; CHECK: [[ROL:%[0-9]+]]:ac, {{[^=]*}} = ROL %0
    ; CHECK-NEXT: %{{[0-9]+}}:ac = COPY [[ROL]]
    ; CHECK-NEXT: {{%[0-9]+}}:ac, {{.*}} = ROL
    %0:ac = COPY $a
    %1:cc = COPY $c
    %2:ac, %3:cc = ROL %0, %1
    %4:ac = COPY %2
    %5:ac, %6:cc = ROL %4, %3
    $a = COPY %5
    RTS implicit $a
...
```
