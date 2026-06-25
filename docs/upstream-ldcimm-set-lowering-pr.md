<!-- STATUS (internal; strip before posting): drafted 2026-06-26. PR body for the LDCImm set-lowering
     robustness fix (fork patch 0012). Posting is user-triggered. Branch to mint:
     wbniv:mos-ldcimm-set-lowering off pristine c798c31416f7. -->

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

A *set* i1 carry, however, can reach MC as **`1`** (a plain i1 `true`) rather than `-1` — for instance the
carry-in materialized for a **16-bit `SBC`**, whose `CarryInit` is selected as `1` and flows through
`LDImm1`/`LDCImm`. The `default` arm is then `llvm_unreachable`: an asserts build **aborts**
(`Unexpected LDCImm immediate.`), and a release build (NDEBUG) executes the `__builtin_unreachable()` as
undefined behavior — it happens to emit `SEC`, so the result is usually correct, but only by luck.

## Reproduction

Any 16-bit subtract under `+mos-a16` reproduces it on an `LLVM_ENABLE_ASSERTIONS=On` build:

```c
volatile unsigned short a = 0xDC13, b = 0x1234, out;
int main(void) { out = (unsigned short)((unsigned)a - b); for (;;) {} }
```

`mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -c sub16.c` aborts at
the `llvm_unreachable` pre-fix and compiles clean post-fix.

## Fix

The operand is an i1 carry value; treat it as the boolean it is — `0` → `CLC`, any nonzero → `SEC`:

```cpp
case MOS::LDCImm:
  OutMI.setOpcode(MI->getOperand(1).getImm() == 0 ? MOS::CLC_Implied
                                                  : MOS::SEC_Implied);
  return;
```

One line; emits the same `SEC`, so it is byte-identical on everything that previously lowered via the
NDEBUG `default` arm, and it removes both the asserts abort and the release UB.

## Test

A `mos`/`mos6502` `llc` `.mir` test that lowers `$c = LDCImm 1` to `sec` (and `LDCImm 0` to `clc`) can be
added. Validated end-to-end via a `+mos-a16` differential corpus + fuzzer (no output change; previously
crashing asserts builds now compile clean).
