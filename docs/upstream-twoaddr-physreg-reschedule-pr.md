# [CodeGen] Avoid register exhaustion when rescheduling physical-register definitions

On `mos6502`, a function that updates byte and word values through a pointer across a call fails with `ran out of registers during register allocation` at `-O1`, `-O2`, `-O3`, `-Os`, and `-Oz`:

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

`TwoAddressInstructionImpl::rescheduleKillAboveMI` moves the argument copy `$a = COPY %arg` above a folded arithmetic instruction that also uses `%arg`. This makes physical `$a` live through the arithmetic until the call. The arithmetic's virtual operands belong to `Ac`, whose only register is `$a`; even spilling cannot provide a legal register for them.

The dependency check already rejects interference with physical operands. Extend it to reject the move when every unreserved register in a crossed virtual operand's class overlaps a live physical definition of the moved instruction. Check all crossed instructions, since an intervening operand can have the same constraint. Classes with another allocatable register still permit the move. Reserved registers are not counted as available, since the allocator never assigns them.

Conservatively require an unreserved class member outside the newly live physical definitions for each crossed virtual operand. Independent values cannot share those registers, and spilling cannot create another class member. The check does not model physical registers that were already live across the crossed instruction before the move; that is the pass's existing blind spot, and this change only stops it from creating a new unallocatable operand by itself.

Add a MIR test covering the accumulator argument, an intervening constrained index, and a legal copy into `$x` with a GPR temporary that has other allocation choices, using LiveIntervals and a separate no-analysis ordering control. Allocate the LiveIntervals output to check the resulting schedule. Add an IR test for the mixed-width call through full code generation at `-O1`, `-O2`, and `-O3`.

Validated against llvm-mos `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63`, checked as upstream `main` on October 10, with only this standalone compiler patch applied:

- The unchanged C-derived IR fails on the retained unpatched backend at `-O1`, `-O2` and `-O3` with register exhaustion, and passes with the guard. `-O0` passes on both.
- The MIR LiveIntervals ordering checks fail before the guard, and allocation of that output fails in the accumulator and intervening-index cases. Both checks pass with the guard; the legal move with spare class members remains permitted.
- Complete MOS CodeGen/MC suites: 140 passed, one unsupported, no failures; Release build with assertions and LTO disabled.

Current C compilation matrix: `mos6502` and `mosw65816`, O0/O1/O2/O3/Os/Oz, with and without the machine verifier. All 24 candidate full-driver compilations and 24 candidate-backend runs pass. The unchanged candidate frontend emits each IR input once for both backends: the preserved unpatched backend passes the four O0 runs and fails all 20 optimized runs with register exhaustion. This split-pipeline baseline is not a separately rebuilt pristine current-base Clang driver.

The original September 22 standalone validation on `742d554bf080` also passed the six-level C matrix and the complete assertion-enabled X86/ARM/AArch64 suites (11,436 passed, 23 expected failures). Those are dated results; other backends, runtime behavior and compile-time benchmarks have not been revalidated on the current base.

This failure was encountered in the C torture test behind the published [By-Value Boundary Trio SNES demo](https://biohack.net/snes/byvaledge/). The shipped demo uses a scoped source workaround. The standalone plain-6502 regressions establish the compiler repair; this PR contains no SNES platform implementation or target configuration.

Assisted-by: OpenAI Codex CLI 0.155.1, model `gpt-6-astra`, xhigh reasoning effort, for the original diagnosis, implementation, tests, validation and PR drafting.

Assisted-by: Claude Code CLI 2.1.278, model `claude-fable-5-1`, high reasoning effort, for the original independent review, reserved-register refinement and full-suite validation.

Assisted-by: OpenAI Codex CLI 0.162.0, model `gpt-6.1-sol`, medium reasoning effort, for the October 10 exact-upstream reconciliation, standalone branch refresh, regression coverage, retained red/green evidence and PR preparation.
