<!-- STATUS (internal; strip before posting): drafted 2026-06-22. Upstream PR for the addrspace(1)
     pointer-argument calling-convention crash (issue #561). Branch NOT pushed, PR NOT opened —
     awaiting user preview. Fork-carried as patches/llvm-mos/0008-mos-dp-arg-cc.patch. -->

# Upstream PR preview — pass `addrspace(1)` pointer arguments in an 8-bit register

> **Status: NOT pushed, PR NOT opened.** Preview for review. Fixes the crash reported in
> [issue #561](https://github.com/llvm-mos/llvm-mos/issues/561).

| | |
|---|---|
| **Base** | `llvm-mos/llvm-mos:main` (branch off `c798c3141`, current upstream tip) |
| **Head (to push)** | `wbniv:mos-dp-arg-cc` |
| **Files** | `llvm/lib/Target/MOS/MOSCallingConv.td` (+10) · `llvm/test/CodeGen/MOS/dp-pointer-arg.ll` (new) |
| **Fixes** | #561 |
| **Carried locally as** | `patches/llvm-mos/0008-mos-dp-arg-cc.patch` (fork; drop once merged + bump the vendor pin) |

## PR title

```
[MOS] Pass addrspace(1) (8-bit direct-page) pointer arguments in an 8-bit register
```

## PR body (as it would appear on GitHub)

A function that takes a pointer in **address space 1** — the 8-bit direct-page space (`p1:8:8` in the MOS
data layout) — as an **argument** crashes the backend. The calling convention assigns *every* pointer
argument to a 16-bit `RS` register pair, but an `addrspace(1)` pointer is only 8 bits wide, so argument
materialization emits a size-mismatched physical-register copy:

```
%0:_(p1) = COPY $rs1        ; Def Size = 8, Src Size = 16
```

`-verify-machineinstrs` rejects it (*"Copy Instruction is illegal with mismatching sizes"*); a release build
without the verifier carries the illegal copy into register allocation and crashes. It reproduces on the
base `mos6502` target — no 65816 / 16-bit features needed:

```c
#define DP __attribute__((address_space(1)))
char d(char DP *p) { return *p; }   // crashes
```

### Cause

`CC_MOS` in `llvm/lib/Target/MOS/MOSCallingConv.td` assigns pointer arguments with:

```tablegen
CCIfPtr<CCAssignToReg<[RS1, RS2, RS3, RS4, RS5, RS6, RS7]>>,
```

`CCIfPtr` is `CCIf<"ArgFlags.isPointer()">` — address-space-blind — so the 8-bit `addrspace(1)` pointer is
handed a 16-bit `RS` slot. This has been latent since `addrspace(1)` direct-page pointers were introduced
(`e618537e7d5e`, *"Use address space 1 for ZP pointers."*); the rule predates it
(`80c2618c0576`, *"Use RISC-V-like calling convention."*) and was correct while every pointer was 16-bit.

### Fix

Assign an 8-bit `addrspace(1)` pointer to an 8-bit register slot — the same pool an `i8` uses — with a rule
placed before the generic `CCIfPtr`:

```tablegen
CCIfPtrAddrSpace<1, CCAssignToReg<[
  A, X, RC2, RC3, RC4, RC5, RC6, RC7, RC8, RC9, RC10, RC11, RC12, RC13, RC14, RC15
]>>,
```

The same rule covers `addrspace(1)` pointer **returns** (there is no separate return CC). Variadic
arguments are unaffected — they already pass on the stack. A DP pointer argument then arrives in an 8-bit
register and dereferences via zero-page-indexed addressing (`lda 0,x` / `sta 0,x`).

### Test

`llvm/test/CodeGen/MOS/dp-pointer-arg.ll` — a load and a store through an `addrspace(1)` pointer argument,
run under `-verify-machineinstrs` (which fails on the unfixed backend) with `CHECK` lines pinning the
zero-page-indexed access.
