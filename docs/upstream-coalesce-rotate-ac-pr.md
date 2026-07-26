# [MOS] Don't coalesce two rotate-referenced values into the A-only `Ac` class (silent miscompile)

<!-- POSTED 2026-07-26 as https://github.com/llvm-mos/llvm-mos/pull/578 (campaign Wave 1, item 2;
     body below minus the H1 and this comment is the as-posted text).
     Staging record: red/green proven on the pristine tip build
     (RED = lit FAIL on unfixed llc; GREEN = official llvm-lit PASS 100% after fix + rebuild).
     Branch mos-coalesce-rotate-ac minted locally in vendor/llvm-mos @ 18244924b3d3 (cut from
     8be054612, same base as 0016) — push blocked by permission layer, part of the user trigger.
     Post commands (title = the H1 above; body = this doc minus the H1 and this comment):
       git -C vendor/llvm-mos push https://github.com/wbniv/llvm-mos.git mos-coalesce-rotate-ac
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-coalesce-rotate-ac --base main \
         --title "[MOS] Don't coalesce two rotate-referenced values into the A-only Ac class (silent miscompile)" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-coalesce-rotate-ac-pr.md)
     Demo links below verified HTTP 200 on 2026-07-26 — re-verify at posting time.
-->

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
- Four SNES demos exercising CRC/LFSR rotate-under-pressure loops are **playable in-browser**
  (bsnes-jg WASM; each page's "Verify fidelity" button re-runs the WRAM self-check live, comparing
  the on-console result against the host-computed reference):
  [crcwall](https://biohack.net/snes/crcwall/) ·
  [lfsr2](https://biohack.net/snes/lfsr2/) ·
  [bitweave](https://biohack.net/snes/bitweave/) ·
  [uarteye](https://biohack.net/snes/uarteye/)

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
