<!-- RETIRED — DO NOT POST (user decision 2026-08-05).
     No current upstream producer emits LDCImm 1, and downstream patch 0027 canonicalizes the
     former a16 producer to LDCImm -1. The direct MIR test manufactures an otherwise unreachable
     state, while accepting every nonzero immediate would weaken the existing invariant check.
     Retained only as investigation and red/green evidence; it is not a PR body or queue item.
     Local branch mos-ldcimm-set-lowering at 60d9d7d25262, based on c798c31416f7.
     Fork carry: patches/llvm-mos/0012-mos-ldcimm-set-lowering.patch.
     Assertions-enabled red/green proof completed 2026-08-05. -->

# [MOS] Lower `LDCImm` set-carry from any nonzero i1, not only `-1`

## Summary

`MOSMCInstLower` lowers `LDCImm` (register class `Cc`, an `i1imm` operand) to `CLC`/`SEC`, but only
recognized the immediates `0` (`CLC`) and `-1` (`SEC`):

```cpp
case MOS::LDCImm:
  switch (MI->getOperand(1).getImm()) {
  default:  llvm_unreachable("Unexpected LDCImm immediate.");
  case 0:   OutMI.setOpcode(MOS::CLC_Implied); return;
  case -1:  OutMI.setOpcode(MOS::SEC_Implied); return;
  }
```

The operand is an `i1imm`, so a *set* carry has two legitimate spellings: sign-extended **`-1`**
(the form the `.td` patterns use) and plain **`1`** (i1 `true`). The backend itself is split on
which form is canonical — `expandLDImm1` normalizes this very value with `!!Val` (yielding `1`)
when the destination is a GPR, but passes it through untouched when the destination is the carry —
yet the MC lowering accepts only `-1`. When a `1` arrives, the `default` arm is
`llvm_unreachable`: an asserts build **aborts** (`Unexpected LDCImm immediate.`), and a release
build (NDEBUG) executes the `__builtin_unreachable()` as undefined behavior (observed to fall
through and emit `SEC` — the correct output, but only by luck).

## Reproduction

The regression is a baseline `mos65c02` MIR input placed beside the existing `LDCImm 0` and
`LDCImm -1` asm-printer cases:

```yaml
name: sec_implied_true
body: |
  bb.0.entry:
    $c = LDCImm 1
    ; CHECK: sec{{$}}
    RTS
    ; CHECK-NEXT: rts
```

With the pre-fix `MOSMCInstLower`, ordinary `llc -mtriple=mos -mcpu=mos65c02` aborts at the
`llvm_unreachable`. With the fix it prints `sec`.

## Fix

The operand is an i1 carry value; treat it as the boolean it is — `0` → `CLC`, any nonzero → `SEC`:

```cpp
case MOS::LDCImm:
  OutMI.setOpcode(MI->getOperand(1).getImm() == 0 ? MOS::CLC_Implied
                                                  : MOS::SEC_Implied);
  return;
```

One line; it removes both the asserts abort and release UB without changing established `0`/`-1`
lowering. Accepting *any* nonzero value — rather than keeping an assert for values outside
`{-1, 0, 1}` — is deliberate: `i1imm` semantics make nonzero *true*, exactly the `!!Val` treatment
the backend already applies to this operand elsewhere.

## Test

`llvm/test/CodeGen/MOS/asm-printer.mir` now covers all three relevant encodings under baseline
`mos65c02`: `0` lowers to `clc`, while both `-1` and `1` lower to `sec`. The new `1` case aborts before
the fix and passes afterward.

This was also verified with a fresh `LLVM_ENABLE_ASSERTIONS=ON` build from the pristine parent and
then the patched branch, using the same standalone MIR input in both runs:

- Before: exit 134 at `MOSMCInstLower.cpp`, `Unexpected LDCImm immediate.`
- After: exit 0 and assembly containing `sec`.
- Focused patched-tree lit test: `CodeGen/MOS/asm-printer.mir` passes (1/1).

## Origin

Found while auditing a crash caused by a plain `1` reaching this generic MC-lowering path. We have
not identified an in-tree producer that emits `LDCImm 1` today — the in-tree patterns and
flag-destination selects consistently use `-1` — so this is a hardening fix: it aligns MC lowering
with the operand's `i1imm` semantics, removes release-mode UB, and supports any future or
out-of-tree producer that spells *true* as `1`. The reproducer and regression test are baseline
`mos65c02` MIR; no 65816 feature, demo ROM, or downstream patch is involved.
