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

`TwoAddressInstructionImpl::rescheduleKillAboveMI` moves the argument copy
`$a = COPY %arg` above a folded arithmetic instruction that also uses `%arg`.
This makes physical `$a` live through the arithmetic until the call. The
arithmetic's virtual operands belong to `Ac`, whose only register is `$a`;
even spilling cannot provide a legal register for them.

The dependency check already rejects interference with physical operands.
Extend it to reject the move when every unreserved register in a crossed
virtual operand's class overlaps a live physical definition of the moved
instruction. Check all crossed instructions, since an intervening operand can
have the same constraint. Classes with another allocatable register still
permit the move. Reserved registers are not counted as available, since the
allocator never assigns them.

Every move this rejects would necessarily have failed allocation: the moved
definition is live through each crossed instruction, and the crossed operand
must occupy a member of its class there, so no assignment exists and spilling
cannot create one. The check does not model physical registers that were
already live across the crossed instruction before the move; that is the
pass's existing blind spot, and this change only stops it from creating a new
unallocatable operand by itself.

Add a MIR test covering the accumulator argument, an intervening constrained
index, and a legal copy into `$x` with a GPR temporary that has other allocation
choices, using both LiveVariables and LiveIntervals. Add an IR test for the
mixed-width call through full code generation at `-O1`, `-O2`, and `-O3`.

Validated against llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (identical
to `main` at the time of writing), with only this patch applied:

- The C reproducer compiles at all six optimization levels, both normally and
  with MachineVerifier enabled. The unpatched compiler fails at every level
  above `-O0`.
- MOS CodeGen and MC tests: 131 pass, one unsupported, including both new tests,
  with and without assertions.
- The MIR ordering checks and the IR test fail on the unpatched compiler.
- The complete `test/CodeGen/X86`, `test/CodeGen/ARM` and `test/CodeGen/AArch64`
  suites pass in an assertion-enabled build: 11,459 tests, 11,436 pass and 23
  expectedly fail, no failures.

Other backends and compile-time benchmarks were not tested.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`,
`xhigh` reasoning effort) for diagnosis, implementation, tests, validation,
and PR drafting.
Assisted-by: Claude Code using Claude Fable 5.1 (`claude-fable-5-1`) for the
independent review, the reserved-register refinement, and the full-suite
validation.
