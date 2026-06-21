<!-- STATUS (internal; strip before posting): drafted 2026-06-22. Root-caused to MOSCallingConv.td:65
     CCIfPtr (assigns every pointer — incl. the 8-bit addrspace(1) DP pointer — to a 16-bit RS pair).
     Reproduces on pristine upstream (our vendor pin == upstream main c798c31). Ready to post (user-triggered).
     Upstream issue for the addrspace(1) pointer-argument calling-convention size mismatch. -->

# [MOS] Calling convention passes an `addrspace(1)` (8-bit direct-page) pointer argument in a 16-bit register → illegal `COPY` (`Def Size = 8, Src Size = 16`)

## Summary

A function that takes a pointer in **address space 1** (the 8-bit direct-page space, `p1:8:8` in the MOS
data layout) as an **argument** crashes the backend. The MOS calling convention assigns *every* pointer
argument to a 16-bit `RS` register pair, but an `addrspace(1)` pointer is only 8 bits wide, so argument
materialization emits a size-mismatched physical-register copy `%vreg:(p1) = COPY $rsN` (8-bit def ← 16-bit
source).

- `-verify-machineinstrs` rejects it: *"Copy Instruction is illegal with mismatching sizes … Def Size = 8,
  Src Size = 16"*.
- An asserts build aborts during register allocation at `llvm_unreachable("Unexpected physical register
  copy.")` (`MOSRegisterInfo::copyCost`).
- A release build **without** `-verify-machineinstrs` does not catch the bad copy and **segfaults** later in
  `MOSLateOptimization`.

This is independent of any 65816 / 16-bit work — it reproduces on the base **`mos6502`** target.

## Reproduce

```c
#define DP __attribute__((address_space(1)))
char d(char DP *p){ return *p; }      // 8-bit addrspace(1) pointer argument
```

```
mos-clang --target=mos -mcpu=mos6502 -Os -std=c23 -mllvm -verify-machineinstrs -c dp.c -o /dev/null
```

The illegal copy is the **argument**, not anything the body does — the IRTranslator output is:

```
# After IRTranslator
bb.1 (%ir-block.1):
  liveins: $rs1
  %0:_(p1) = COPY $rs1                                    ; <-- 8-bit p1 def ← 16-bit $rs1 source
  %1:_(s8) = G_LOAD %0:_(p1) :: (load (s8) from %ir.0, addrspace 1)
  $a = COPY %1:_(s8)
  RTS implicit $a

*** Bad machine code: Copy Instruction is illegal with mismatching sizes ***
- function:    d
- instruction: %0:_(p1) = COPY $rs1
Def Size = 8, Src Size = 16
fatal error: error in backend: Found 1 machine code errors.
```

Any use of an `addrspace(1)` pointer *argument* triggers it (deref, cast to a near pointer, or just
`(intptr_t)p`); a `addrspace(1)` *local* (not an argument) is fine, and a default-space pointer argument is
fine. Minimal trigger matrix:

| program | result |
|---------|--------|
| `char d(char DP *p){ return *p; }` | **crash** |
| `int d(char DP *p){ return (int)(__INTPTR_TYPE__)p; }` (no deref) | **crash** |
| `char d(void){ static char DP *p; return *p; }` (DP **local**, not arg) | ok |
| `char d(char *p){ return *p; }` (default-space arg — control) | ok |

### Asserts build (no `-verify-machineinstrs`)

```
Unexpected physical register copy.
UNREACHABLE executed at llvm/lib/Target/MOS/MOSRegisterInfo.cpp:1059!
  llvm::MOSRegisterInfo::copyCost(...)
  llvm::MOSRegisterInfo::getRegAllocationHints(...)
  llvm::RAGreedy::selectOrSplitImpl(...)   ; <-- aborts during register allocation
```

### Release build (no `-verify-machineinstrs`)

```
Running pass 'MOS Late Optimizations' on function '@d'
  (anonymous namespace)::MOSLateOptimization::runOnMachineFunction(...)   ; <-- SIGSEGV
```

## Where

`llvm/lib/Target/MOS/MOSCallingConv.td`, `CC_MOS`:

```tablegen
// Pointers are preferentially assigned to imaginary registers so indirect
// addressing modes work without additional copying.
//
// RS0 is skipped since it's the stack pointer.
CCIfPtr<CCAssignToReg<[RS1, RS2, RS3, RS4, RS5, RS6, RS7]>>,
```

`RS1`–`RS7` are 16-bit register pairs. `CCIfPtr` matches **any** pointer regardless of address space or
width — `MOSCallLowering.cpp::adjustArgFlags` sets `Flags.setPointer()` /
`Flags.setPointerAddrSpace(Ty.getAddressSpace())` precisely so this predicate can see the pointer, but the
rule does not distinguish the 8-bit `addrspace(1)` pointer from the 16-bit default-space pointer. So an
`addrspace(1)` argument is given a 16-bit `RS` home, and the subsequent `(p1) = COPY $rsN` is size-mismatched.

The downstream abort site is `MOSRegisterInfo::copyCost` (`llvm_unreachable("Unexpected physical register
copy.")`), reached because the 8-bit-vreg ↔ 16-bit-physreg copy has no legal cost/lowering.

## Regression — introduced by

[`e618537e7d5e`](https://github.com/llvm-mos/llvm-mos/commit/e618537e7d5e) — *"Use address space 1 for ZP
pointers."* (2022-07-25). It introduced the 8-bit `addrspace(1)` direct-page pointer **without** a
calling-convention carve-out for its width. The pointer-argument rule
`CCIfPtr<CCAssignToReg<[RS1..RS7]>>` predates it —
[`80c2618c0576`](https://github.com/llvm-mos/llvm-mos/commit/80c2618c0576) *"Use RISC-V-like calling
convention."* (2021-09-22) — and is **address-space-blind** (`CCIfPtr` ≙ `CCIf<"ArgFlags.isPointer()">`),
correct while every pointer was 16-bit. So the defect is the interaction: once `addrspace(1)` pointers
exist (2022), passing one as an argument routes it through the 16-bit `RS` rule. Both commits are
ancestors of current `main`; the bug has been latent since 2022.

## Likely fix directions

Make the pointer-argument rule address-space-aware so an 8-bit `addrspace(1)` pointer is assigned an 8-bit
home (like the existing `i8` rule — `A`, then `X`, then the `RC*` argument registers) rather than a 16-bit
`RS` pair. For example, gate the existing rule to the 16-bit default space and add a separate rule for the
direct-page space:

```tablegen
CCIfPtr<CCIfPtrAddrSpace<0, CCAssignToReg<[RS1, RS2, RS3, RS4, RS5, RS6, RS7]>>>,
CCIfPtr<CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2, RC3, /* … */]>>>,
```

(or equivalently coerce/truncate the value to 8 bits at argument materialization for `addrspace(1)`). The
exact predicate spelling is yours to choose — the fix is that an 8-bit pointer must not be handed a 16-bit
register slot. The same applies symmetrically to `addrspace(1)` pointer *returns* and to passing one as a
call argument.

## Notes

Found while adding 24-bit far-pointer (`addrspace(2)`) support downstream, but this is a pre-existing defect
in the **upstream** handling of the existing 8-bit `addrspace(1)` space — it needs no downstream patches and
reproduces on a pristine build at the base `mos6502` target. Verified against `llvm-mos/llvm-mos` main
`c798c31` (the data-layout `p1:8:8` at `MOSTargetMachine.cpp:76`; the `CCIfPtr` rule at
`MOSCallingConv.td:65`; the abort at `MOSRegisterInfo.cpp:1059`).

Happy to provide the full asserts backtrace, the pre-PEI MIR, or a reduced `.ll`.
