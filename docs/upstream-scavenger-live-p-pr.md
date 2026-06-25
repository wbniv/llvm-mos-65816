<!-- STATUS (internal; strip before posting): drafted 2026-06-26. PR body for the register-scavenger
     live-P fix (fork patch 0011). Supersedes the issue-only draft 321-upstream-scavenger-nz-issue.md
     (which described the bug + why the obvious fixes don't work; this is the actual fix). Posting is
     user-triggered. Branch to mint: wbniv:mos-scavenger-live-p-save off pristine c798c31416f7. -->

# [MOS] Register scavenger: preserve a live processor-status register across an unbalanced stack range

## Summary

`MOSRegisterInfo::saveScavengerRegister` assumed the N/Z processor-status flags are dead at every
register-scavenging point, and that a live `$p` only ever needs preserving across a *push/pull-balanced*
range. Both assumptions break under longer flag live ranges (readily produced by 16-bit-accumulator
codegen, `+mos-a16`): a 16-bit compare/ALU keeps N (or Z) live across a frame-index materialization whose
carry the scavenger must place in `$c` — a sub-register of `$p` — so the *whole* `$p` must be preserved,
and the scavenge lands inside an **unbalanced** range. The old code then emitted illegal MIR:

```
*** Bad machine code: Using an undefined physical register ***          - PH $p
*** Bad machine code: Illegal physical register for instruction ***     - $rcN = STImag8 $p   ($p is not a GPR)
                                                                         - $p   = LDImag8 $rcN ($p is not a GPR)
```

An asserts build aborts earlier at `assertNZDeadAt` (`"expected N to be free when saving scavenger
register"`); a release build emits the illegal `STImag8 $p` that `-verify-machineinstrs` rejects.

## Root cause

`scavengeFrameVirtualRegs` materializes a frame-index address post-RA via `expandAddrLostk`/`expandAddrHistk`
as `LDCImm 0; ADCImm`, which introduces a **carry virtual register** of class `Pc` (whose only physical home
is `$c`, a sub-register of `$p`). When a 16-bit compare/ALU keeps N (or Z) live across that point, the whole
`$p` is live and must be spilled to free `$c`. But:

1. **`$p` has no GPR spill home.** `STImag8`/`LDImag8` are GPR-only, so `saveScavengerRegister`'s
   `Reg == MOS::P` fall-through `STImag8 {Save}, {P}` is structurally illegal.
2. **The range is push/pull-unbalanced.** `saveScavengerRegister` takes the hard-stack (`PHP`/`PLP`) path only
   when `pushPullBalanced(I, UseMI)`; here the scavenge lands inside an unbalanced run (the soft-stack spill
   code does net pushes between `I` and `UseMI`), so a plain `PLP` at `UseMI` would pop the wrong byte.

The N/Z and carry bits are independent sub-registers of `$p`, but the scavenger spills `$p` atomically: the
frame-address `ADC` clobbers *all* of `$p`, so the live compare flag must be preserved across it.

The "N/Z is dead here" premise comes from
[`a367c3bb51d0`](https://github.com/llvm-mos/llvm-mos/commit/a367c3bb51d0) ("Replace CMPTerm;BR with a new
CmpBr", 2024-02-06) — the comment *"NZ cannot be live at this point, since virtual registers are never
inserted into CmpBr instructions"* was true for the patterns of the day but is not a general invariant.

## Reproduction

A recursive function holding several 16-bit values live across the self-call (register pressure → frame-vreg
scavenging) together with a 16-bit compare that keeps N/Z live across that point. Crashes at `-O1`/`-Os`;
compiles clean at `-O0`. Most readily with `+mos-a16`, but the defect is in the generic scavenger path.

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

`mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm
-verify-machineinstrs -c repro.c` crashes pre-fix and compiles clean post-fix.

## Fix

`MOSRegisterInfo.cpp`:

- **Split `P` out of the shared A/Y/P case.** The balanced range keeps the existing `PHP`/`PLP` (which
  round-trips all of P). For an **unbalanced** range, route `$p` *hard-stack-neutrally* through a dead 8-bit
  index register into the reserved `RC17` slot:

  ```
  save:    PHP ; PL<idx> ; ST<idx> RC17
  restore: LD<idx> RC17 ; PH<idx> ; PLP
  ```

  Each half is push/pull-balanced (net-0 stack delta), so it is independent of the surrounding imbalance and
  doesn't perturb other scavenges. The courier pull/load transiently clobbers N/Z, but only inside the
  borrowed region where the saved flags aren't read; the final `PLP` restores the full P. Routing through an
  **index register** (not A) makes it width-safe: `MOSInsertREPSEP` runs after scavenging and classifies any
  index push/pull/load/store as `XW_X8`, so the couriers stay 8-bit even under `+mos-xy16`.

- **Flag a `PHP` of a not-reaching-def `$p` as `undef`.** Because the carry vreg is `Pc`-class, the scavenger
  may preserve `$p` even where `$p` holds no live value; the resulting `PHP` reads an undef `$p`, which the
  verifier rejects unless the operand is flagged `undef` (a reaching-definition test, distinct from
  liveness).

- **Drop `assertNZDeadAt`.** Its premise (N/Z dead at every scavenge point) is exactly the false invariant
  above. Under longer flag live ranges N/Z can be live across A/Y saves too; the A/Y restore (`LD`/`PL`)
  transiently clobbers physical N/Z, but the architected value is preserved by the scavenger's own
  interleaved P save/restore. Correctness is enforced by `-verify-machineinstrs` and differential testing.

- **Widen `canSaveScavengerRegister(MOS::P)`** to report saveable when balanced *or* (`hasGPRStackRegs` and a
  dead index register exists at both ends), matching the new capability.

Default 8-bit codegen is unaffected — the new P-arm only runs when a live `$p` must be preserved across an
unbalanced range, which only longer-flag-live-range pressure (`+mos-a16`/`+mos-xy16`) produces.

## Test

`-verify-machineinstrs` is clean on the repro under both `+mos-a16` and `+mos-xy16`, on Release and on a
`LLVM_ENABLE_ASSERTIONS=On` build (the `assertNZDeadAt` no longer aborts). A four-way differential
(host-computed == default-8bit == `+mos-a16` == `+mos-xy16`, on two independent SNES emulators) agrees on the
program's result, and a broad `+mos-a16`/`+mos-xy16` differential corpus + fuzzer shows no regression and no
new verifier failures. (A `mos`/`mos6502` `llc` MIR test can be distilled from the pre-PEI MIR on request.)
