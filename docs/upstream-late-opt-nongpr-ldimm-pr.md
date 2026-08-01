# [MOS] Fix null-pointer crash in mos-late-opt on an LDImm with a non-GPR destination (SPC700)

<!-- POSTED 2026-07-31 as https://github.com/llvm-mos/llvm-mos/pull/584 (from the 138 LZSS-gallery
     far-decode investigation; see docs/plans/2026-07-27-138-lzss-far-decode-mos-late-optimization-crash.md
     and docs/plans/2026-07-31-138-guard-hardening-followup.md for provenance).
     UPDATED 2026-07-31 (critique-improvements pass, see
     docs/plans/2026-07-31-upstream-pr-critique-improvements.md): body below is the as-posted v2
     text — Fix section shows the shipped defensive-invalidation guard (branch commit 7eedb14),
     sibling TA-handler hardening added, null-store crash claim softened to "in practice".
     Branch wbniv:mos-late-opt-nongpr-ldimm (v1 ae5c399e, defensive guard 7eedb14a).
-->

## Summary

`MOSLateOptimization::combineLdImm` tracks the last immediate loaded into each of
`A`, `X` and `Y` so it can rewrite a redundant `LD_ #imm` into a cheaper `T__`,
`IN_` or `DE_`. It keeps that state in three `ImmLoad` structs and selects one
with a `switch` over the destination register:

```cpp
    ImmLoad *Load = nullptr;
    ...
    // Store this instruction (changed or not) and the new register value.
    switch (Dst) {
    case MOS::A: Load = &LoadA; break;
    case MOS::X: Load = &LoadX; break;
    case MOS::Y: Load = &LoadY; break;
    }

    Load->MI = &MI;
    Load->Val = Val;
```

`Load` starts each iteration as `nullptr` and is only ever assigned inside
switches over `{A, X, Y}`, but the store through it is unconditional. Any
`LDImm` whose destination is none of those three writes through null.

That is not a hypothetical destination. On SPC700, `MOSInstrInfo::getRegClass`
deliberately widens `LDImm`'s destination class so the pseudo can model
`mov dp, #imm`:

```cpp
  // On SPC700, LDImm can be used for imaginary registers.
  if (STI->hasSPC700() && MCID.getOpcode() == MOS::LDImm && OpNum == 0)
    return &MOS::Anyi8RegClass;
```

So `$rcN = LDImm imm` is legal, `-verify-machineinstrs`-clean MIR that the
allocator produces from ordinary C, and `mos-late-opt` crashes on it.

## Reproduction

Seven lines of plain C, no attributes, no target features:

```c
volatile unsigned char io;

unsigned char f(unsigned char n) {
  unsigned char a = 7, b = 9, c = 11, d = 13, e = 15, g = 17, h = 19, i = 21;
  while (n--) {
    io = a; io = b; io = c; io = d;
    io = e; io = g; io = h; io = i;
    a += n;
    b ^= n;
  }
  return a + b + c + d + e + g + h + i;
}
```

```console
$ clang --target=mos -mcpu=mosspc700 -Os -S -o /dev/null repro.c
...
3.	Running pass 'Function Pass Manager' on module 'repro.c'.
4.	Running pass 'MOS Late Optimizations' on function '@f'
 #4 ... (anonymous namespace)::MOSLateOptimization::runOnMachineFunction(llvm::MachineFunction&)
clang: error: clang frontend command failed due to signal
```

Crashes at `-O1`, `-O2`, `-Os` and `-Oz`; clean at `-O0`, where nothing is
allocated to an imaginary register. Eight simultaneously-live bytes is the
smallest count that reliably pushes one of the constants out of `A`/`X`/`Y`;
with four it stays in the GPRs and does not crash.

Reduced to MIR, the whole trigger is one instruction:

```console
$ llc -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt -o - late-opt-spc700.mir
2.	Running pass 'MOS Late Optimizations' on function '@ldimm_imag8_only'
Segmentation fault
```

The input MIR round-trips clean through `-run-pass=none -verify-machineinstrs`,
so this is not a garbage-in case — the pass has to handle it.

The defect is a null-pointer *store*, which in practice faults immediately
(page zero is unmapped on every host we build on), so a build that completes
has not been mis-optimized through this path.

## Fix

Skip the tracking for a non-GPR destination — and, defensively, invalidate any
tracked GPR such an instruction reports modifying. No destination that aliases
a GPR exists today, so the invalidation checks are expected to do nothing; they
are there so a future widening of `LDImm`'s destination class cannot turn the
skip into a stale-value rewrite.

```cpp
    // Process LD_ #.
    Register Dst = MI.getOperand(0).getReg();

    // LDImm's destination is not always a GPR. MOSInstrInfo::getRegClass
    // widens it to Anyi8 on SPC700, where `$rcN = LDImm imm` is how
    // `mov dp, #imm` is modelled. Only A, X and Y take part in the rewrites
    // below; an imaginary destination writes none of them, so there is
    // nothing to rewrite. Invalidate any tracked GPR the instruction does
    // modify so a future widening of LDImm's destination class cannot turn
    // this skip into a stale-value rewrite (no such destination exists
    // today; these checks are expected to do nothing).
    if (!MOS::GPRRegClass.contains(Dst)) {
      if (MI.modifiesRegister(MOS::A, TRI))
        LoadA.MI = nullptr;
      if (MI.modifiesRegister(MOS::X, TRI))
        LoadX.MI = nullptr;
      if (MI.modifiesRegister(MOS::Y, TRI))
        LoadY.MI = nullptr;
      continue;
    }

    int64_t Val = MI.getOperand(1).getImm();
```

An imaginary-destination load writes no GPR, so the values tracked for `A`,
`X` and `Y` remain valid across it. The second test case pins that — a `TAX`
rewrite still fires across an intervening imaginary-destination load.

Alternatives considered, briefly: `default: llvm_unreachable(...)` is wrong
because the case is legal and reachable (and is UB rather than a diagnostic in
release builds); giving SPC700 its own opcode would remove the surprise at
source but rewrites a deliberate modelling decision across ISel, the asm
printer and the post-RA expanders — a large blast radius for a missing guard
in one consumer.

The PR also hardens the sibling `TA` handler earlier in `combineLdImm`, which
has the same shape: a `switch` over `{X, Y}` feeding an unconditional store
through the selected pointer. It is unreachable today (`TA`'s destination
class is XY-only), but this function is exactly where "unreachable today"
already failed once, so the handler now falls through to the generic
invalidation path instead of trusting the switch to be exhaustive.

## Tests

`llvm/test/CodeGen/MOS/late-opt-spc700.mir`, alongside the existing
`late-opt.mir` / `late-opt-65c02.mir` / `late-opt-65816.mir`:

- `ldimm_imag8_only` — the minimal crasher; the primary assertion is "no crash
  and machine verification succeeds".
- `ldimm_imag8_between_gprs` — an imaginary-destination load between two GPR
  loads of the same value; pins that it is transparent to the `A`/`X`/`Y` value
  tracking and does not block the `LDX #imm` → `TAX` rewrite.

Red/green: both `llc` invocations above SIGSEGV before the change; `llvm-lit`
passes after it.

## Real-world sighting

Found while compiling a 65816 LZSS decompression gallery demo for the SNES
([playable here](https://biohack.net/snes/lzss-gallery/)), where a 32-bit
imaginary (far-pointer) register reached the same null store from a different
direction. The SPC700 path above is the minimal, upstream-only formulation and
needs none of that context to reproduce.
