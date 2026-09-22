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

Stock `mos6502`, `-O0`, no downstream features. `strlen-4.c` from the gcc C torture suite
(`gcc.c-torture/execute/strlen-4.c`) fails on the pinned upstream:

```sh
clang --target=mos -mcpu=mos6502 -O0 -mllvm -verify-machineinstrs -c strlen-4.c
# *** Bad machine code: Using an undefined physical register ***   (After Prologue/Epilogue Insertion)
# - function:    test_array_ptr
# - instruction: PH $p
```

An assertion-enabled build aborts earlier in the same pass at `assertNZDeadAt`. A 65-line reduction of
that file (its `test_array_ptr` with the string table and the other functions emptied) still fails the
same way; it is the source of the new regression test. The mechanism at `-O0`: the fast register
allocator reloads a spilled pointer between the `sec` that seeds a 16-bit subtraction and the `sbc` that
consumes it,

```text
renamable $c = LDImm1 -1                                            ; sec
renamable $a = LDImm 0
renamable $rs1, dead early-clobber renamable $rs2 = LDStk %stack.6, 0   ; reload from a frame slot past offset 255
renamable $a, renamable $c, dead renamable $v = SBCIndirIdx killed renamable $a, renamable $rs1, killed renamable $y, killed renamable $c
```

so the frame-index expansion of that reload (an `AddrLostk`/`AddrHistk` carry chain once the frame is
larger than 255 bytes) must scavenge a carry register while `$c` is live, and `$p` has to be preserved
around it. That range is balanced, so the existing `PHP … PLP` path is taken; at another scavenge in the
same block the preceding `ADCImag8` has dead-flagged `$c` and `$v`, so nothing of `$p` is available and
the `PHP` reads an undefined `$p`. With the fix, that push is `PH undef $p` and the pushes where `$c` is
available stay `PH $p`.

The original 16-bit reproducer (recursive function with several 16-bit values live across the self-call,
`-Os` with `+mos-a16`) still reproduces the unbalanced-range half on the downstream tree; it needs
downstream features and is kept in the project's records rather than here.

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

- **Flag a `PHP` of a wholly-unavailable `$p` as `undef`.** Because the carry vreg is `Pc`-class, the
  scavenger may preserve `$p` even where `$p` holds no value at all; the resulting `PHP` reads an undef `$p`,
  which the verifier rejects unless the operand is flagged `undef`.

  The predicate (`hasNoAvailableValue`) mirrors `MachineVerifier`'s own bookkeeping rather than
  approximating it. The verifier maintains a **forward availability** set — block live-ins, plus each def,
  minus each kill/dead operand — and accepts a use of a composite register when *any* sub-register is in it
  ("We are fine if just any subregister has a defined value"). So the question is "is any sub-register of
  `$p` available here", answered with `LivePhysRegs::addLiveIns` + `stepForward` + `available()`.

  It is deliberately neither of the two nearby approximations. A *reaching-definition* scan under-fires: an
  ALU chain defines `$c` repeatedly and dead-flags the last one, so a modifier is found above while nothing
  is available at the `PHP`. A *backward-liveness* query never fires at all: `$p` is live by backward
  dataflow at this very point, because this `PHP` uses it.

  Erring is one-sided and the test pins both sides. Failing to flag `undef` is a verifier complaint;
  flagging a genuinely live `$p` would let a flag def move or die, so `scavenger-p-undef.mir` asserts the
  plain `PH $p` in the case where `$c` *is* available as well as the `PH undef $p` where it is not.

- **Only consult liveness when the function tracks it.** Both helpers read block live-ins, which asserts
  unless the function has accurate liveness (`getProperties().hasTracksLiveness()`); MIR tests without
  `tracksRegLiveness`, such as the existing `scavenger.mir`, reach `saveScavengerRegister` for `$p`. In that
  case the `PHP` is left unflagged (the verifier does not check physical-register liveness there, and an
  unflagged use can never miscompile) and no index register is reported dead, so `$p` is saved on the
  balanced hard-stack path exactly as before.

- **Drop `assertNZDeadAt`.** Its premise (N/Z dead at every scavenge point) is exactly the false invariant
  above. Under longer flag live ranges N/Z can be live across A/Y saves too; the A/Y restore (`LD`/`PL`)
  transiently clobbers physical N/Z, but the architected value is preserved by the scavenger's own
  interleaved P save/restore. Correctness is enforced by `-verify-machineinstrs` and differential testing.

- **Widen `canSaveScavengerRegister(MOS::P)`** to report saveable when balanced *or* (`hasGPRStackRegs` and a
  dead index register exists at both ends), matching the new capability.

Stock 8-bit codegen reaches the balanced half of this at `-O0`: the fast register allocator reloads a
spilled pointer between the `sec` that seeds a 16-bit subtraction and the `sbc` that consumes it, so the
frame-index expansion of that reload has to scavenge a carry while `$c` is live, and the resulting `PHP`
can read a `$p` with no available value (see the reproduction below). The unbalanced arm needs
`PHX`/`PHY` and so only runs on 65C02-class targets; on an NMOS 6502 an unbalanced live-`$p` range now
reports a fatal error instead of emitting the illegal `STImag8 $p` (which a release build would have
assembled as garbage). No such range appears anywhere in the corpus below.

## Test

`llvm/test/CodeGen/MOS/scavenger-p-undef-6502.ll`: the `strlen-4.c` reproducer reduced with
`llvm-reduce` to one `-O0` function on stock `mos6502`, run with
`-stop-after=prolog-epilog -verify-machineinstrs`. It pins both directions of the `undef` predicate: the
push where nothing of `$p` is available must be `PH undef $p` (the verifier rejects it otherwise), and the
push where `$c` is live must remain a plain `PH $p` (an over-eager `undef` would let that flag definition
move or die). Before the fix it fails the verifier; an assertion-enabled build aborts in `assertNZDeadAt`.

Validation on the pinned base `742d554bf08042b8df93d791c335260fadd16643` (identical to `main` at the
time of writing), assertions enabled, comparing the backend without and with this change:

- gcc `c-torture/execute` (1,390 of 1,656 files compile with the pinned Clang) at `-O0`, `-O2` and `-Os`
  with MachineVerifier, 4,170 comparisons: exactly one outcome changes, `strlen-4.c` at `-O0` compiles;
  no compilation newly fails, and all 4,090 pairs that succeed on both sides produce identical assembly.
  The fatal error added for an unbalanced live-`$p` range without index-register stack operations is not
  reached anywhere in the corpus.
- The complete MOS CodeGen and MC suites pass with the new test.

On the downstream tree the original `+mos-a16` reproducer and MIR test still exercise the unbalanced
arm (`PHP; PL<idx>; ST<idx> RC17` / `LD<idx> RC17; PH<idx>; PLP`), and a four-way emulator differential
(host == default == `+mos-a16` == `+mos-xy16` on MAME and bsnes-jg) agrees on the program results; that
evidence needs downstream features and is not part of this submission.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`, `high`
reasoning effort) for the stock-6502 reachability analysis, the reduced reproducer and regression
test, the corpus differential, and the PR text revision.
