# [CodeGen] Avoid register exhaustion when rescheduling physical-register definitions

On `mos6502`, a function that updates byte and word values through a pointer
across a call fails with `ran out of registers during register allocation` at
`-O1`, `-O2`, `-O3`, `-Os`, and `-Oz`:

```c
#include <stdint.h>
extern uint16_t ext(uint16_t, uint16_t);

__attribute__((noinline))
void stage(uint16_t *p, uint16_t k) {
    uint16_t a = (uint16_t)(p[0] + k);
    uint16_t b = (uint16_t)(p[1] ^ a);
    uint8_t c = (uint8_t)(((uint8_t *)p)[4] + (uint8_t)b);
    p[0] = (uint16_t)(ext(a, 13849u) + b);
    p[1] = (uint16_t)(b - (uint16_t)c);
    ((uint8_t *)p)[4] = (uint8_t)((a >> 8) ^ c);
}
```

```sh
clang --target=mos -mcpu=mos6502 -Os -c mixed-width-call.c
```

This was encountered in the C torture test behind the
[By-Value Boundary Trio SNES demo](https://biohack.net/snes/byvaledge/).
The standalone C input above also reproduces it on unmodified upstream
`mos6502`; no downstream target features are needed.

`TwoAddressInstructionImpl::rescheduleKillAboveMI` moves the argument copy
`$a = COPY %arg` above a folded arithmetic instruction that also uses `%arg`.
This makes physical `$a` live through the arithmetic until the call. The
arithmetic's virtual operands belong to `Ac`, whose only register is `$a`;
even spilling cannot provide a legal register for them.

The dependency check already rejects interference with physical operands.
Extend it to reject the move when every register in a crossed virtual operand's
class overlaps a live physical definition of the moved instruction. Check all
crossed instructions, since an intervening operand can have the same constraint.
Classes with another available register still permit the move.

Add a MIR test covering the accumulator argument, an intervening constrained
index, and a legal copy into `$x` with a GPR temporary that has other allocation
choices, using both LiveVariables and LiveIntervals. Add an IR test for the
mixed-width call through full code generation at `-O1`, `-O2`, and `-O3`.

Validated against llvm-mos `742d554bf08042b8df93d791c335260fadd16643`, with
only this patch applied:

- The C reproducer compiles at all six optimization levels, both normally and
  with MachineVerifier enabled. The unpatched compiler fails at every level
  above `-O0`.
- MOS CodeGen and MC tests: 131 pass, one unsupported, including both new tests.
- The MIR ordering checks and the IR test fail on the unpatched compiler.
- A separate assertion-enabled build passes 231 focused existing regressions:
  169 X86, 29 ARM, and 33 AArch64, with no failures or skips. The selection covers
  two-address processing, register allocation, coalescing, physical registers,
  tied operands, and commutation; all nine tests requiring assertions pass.
- Both new MOS tests also pass in the assertion-enabled build.

X86, ARM, and AArch64 coverage is limited to this focused selection. Other
backends and compile-time benchmarks were not tested.
