# [MOS] Register allocation fails for mixed byte/word updates across a call on mos6502

**Local status, September 22:** diagnosed and fixed by
[patch 0029](../patches/llvm-mos/0029-llvm-twoaddr-physreg-reschedule.patch).
The [fix PR draft](upstream-twoaddr-physreg-reschedule-pr.md) supersedes this
unposted issue draft. The baseline reproduction below remains valid.

The patched compiler passes the six-level C compilation matrix, and the MOS
CodeGen/MC suites report 131 pass / one unsupported. A separate build with
assertions enabled passes 231 focused X86/ARM/AArch64 regressions and both new
MOS tests, with no failures or skips. See the
[validation record](pr-preparations/2026-09-22/0029-validation.md) and
[backend coverage](pr-preparations/2026-09-22/0029-cross-target-validation.md#backend-coverage-at-the-pinned-revision).
The fix PR remains prepared locally and unposted.

Compiling the following C function for plain `mos6502` fails with `ran out of
registers during register allocation` at `-O1`, `-O2`, `-O3`, `-Os`, and `-Oz`.
`-O0` succeeds. The failure does not require MachineVerifier, inline assembly,
target feature flags, or downstream compiler patches.

This was encountered while compiling the C torture test behind the
[By-Value Boundary Trio SNES demo](https://biohack.net/snes/byvaledge/)
([local source](../examples/snes/byvaledge.c)). Its original five-byte record-update stage included a
multiply lowered to a library call. The standalone reproducer below expresses
the failing shape with an external function call and ordinary pointer accesses.
The demo currently uses a source workaround that moves the problematic call out
of that update sequence.

## Reproducer

Save as `mixed-width-call.c`:

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
clang --target=mos -mcpu=mos6502 -Os -c mixed-width-call.c -o mixed-width-call.o
```

Observed result, exit status 1:

```text
error: <unknown>:0:0: ran out of registers during register allocation in function 'stage'
1 error generated.
```

Expected: successful compilation. `p` can point to an array of at least three
`uint16_t` objects; the byte access uses its character representation. The
declaration of `ext` is sufficient for this compile-only reproducer.

## Tested upstream revision

Reproduced September 22, 2026, with Clang and the backend built from unmodified
[`742d554bf08042b8df93d791c335260fadd16643`](https://github.com/llvm-mos/llvm-mos/commit/742d554bf08042b8df93d791c335260fadd16643),
which was also upstream `main` when checked that day. This is a complete C-to-object
compilation with the stock frontend; no intermediate IR or MIR was edited.

The compiler reports Clang `24.0.0git`. It is a Release build with compiler
assertions disabled and the MOS target enabled.

| Optimization | Normal compilation | With `-mllvm -verify-machineinstrs` |
|---|---|---|
| `-O0` | Pass | Pass |
| `-O1` | Register-exhaustion error | Same error |
| `-O2` | Register-exhaustion error | Same error |
| `-O3` | Register-exhaustion error | Same error |
| `-Os` | Register-exhaustion error | Same error |
| `-Oz` | Register-exhaustion error | Same error |

The two-address pass hoists the physical accumulator argument copy across
arithmetic whose operands can only use that accumulator. Patch 0029 rejects
that rescheduling when a crossed virtual register's entire class overlaps the
moved instruction's live physical definitions. The report establishes a hard
compilation failure; it does not claim a runtime miscompile or global minimality.
