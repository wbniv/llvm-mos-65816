# [MOS] Fix null-pointer crash in `mos-late-opt` on an `LDImm` with a non-GPR destination (SPC700)

<!-- NOT POSTED. Ready-to-post artifact; posting is user-triggered.
     Body below minus the H1 and this comment is the as-posted text.
     Staging record: red/green proven — RED = SIGSEGV on the unfixed
     build/upstream-llc (pristine tip) AND on the fork toolchain; GREEN = llvm-lit
     PASS after the fix + rebuild.
     Branch mos-late-opt-nongpr-ldimm to mint from the current upstream tip.
     Post commands (title = the H1 above; body = this doc minus the H1 and this comment):
       git -C vendor/llvm-mos push https://github.com/wbniv/llvm-mos.git mos-late-opt-nongpr-ldimm
       gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-nongpr-ldimm --base main \
         --title "[MOS] Fix null-pointer crash in mos-late-opt on an LDImm with a non-GPR destination (SPC700)" \
         --body-file <(sed '2,/^-->$/d; 1d' docs/upstream-late-opt-nongpr-ldimm-pr.md)
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
`LDImm` whose destination is none of those three writes to address `0`.

That is not a hypothetical destination. On SPC700, `MOSInstrInfo::getRegClass`
deliberately widens `LDImm`'s destination class so the pseudo can model
`mov dp, #imm`:

```cpp
  // On SPC700, LDImm can be used for imaginary registers.
  if (STI->hasSPC700() && MCID.getOpcode() == MOS::LDImm && OpNum == 0)
    return &MOS::Anyi8RegClass;
```

So `$rcN = LDImm imm` is legal, `-verify-machineinstrs`-clean MIR that the
allocator produces from ordinary C, and `mos-late-opt` segfaults on it.

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

The crash is a null-pointer *store* that faults immediately, so it is always a
hard crash and never a silent miscompile: a build that completes cannot have
been mis-optimized through this path.

## Fix

Skip the tracking entirely for a non-GPR destination:

```cpp
    // Process LD_ #.
    Register Dst = MI.getOperand(0).getReg();

    // LDImm's destination is not always a GPR. MOSInstrInfo::getRegClass
    // widens it to Anyi8 on SPC700, where `$rcN = LDImm imm` is how
    // `mov dp, #imm` is modelled. Only A, X and Y take part in the rewrites
    // below, and an imaginary destination writes none of them, so there is
    // nothing to rewrite here and no tracked value to invalidate.
    if (!MOS::GPRRegClass.contains(Dst))
      continue;

    int64_t Val = MI.getOperand(1).getImm();
```

Skipping is the correct semantic rather than merely a safe one: `$rcN = LDImm imm`
writes no GPR, so the values tracked for `A`, `X` and `Y` remain valid across it
and must *not* be invalidated. The second test case pins that — a `TAX` rewrite
still fires across an intervening imaginary-destination load.

`default: llvm_unreachable(...)` would be wrong here: the case is legal, and in a
release build it is UB rather than a diagnostic, which is exactly how this stayed
a silent segfault. Giving SPC700 its own opcode instead of widening `LDImm`'s
destination class would remove the surprise at source, but it rewrites a
deliberate modelling decision across instruction selection, the asm printer and
the post-RA expanders — a large blast radius for what is a missing guard in one
consumer.

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

Found while compiling a 65816 LZSS decompression gallery demo for the SNES,
where a 32-bit imaginary (far-pointer) register reached the same null store from
a different direction. The SPC700 path above is the minimal, upstream-only
formulation and needs none of that context to reproduce.
