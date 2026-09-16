# MOS: "ran out of registers" on mixed-width accesses through one pointer across a call

> **STATUS 2026‑09‑16: OPEN.** Found by **#154 `byvaledge`** (Round 8 Cluster C) on its first
> compile. This is **not** a `+mos-a16` / `+mos-xy16` / 65816 defect and **not** a regression in
> this fork: it reproduces on **pristine upstream `llvm-mos` `llc`**, with the **pristine MOS
> datalayout**, at `-mcpu=mos6502`, `-O1` and above. It is a hard **error**, not a miscompile —
> the compiler refuses to emit code for a twelve-line C function with no inline asm, no
> aggregates, and no target features.
>
> **No backend fix is attempted here** — this is written up for separate dispatch. `#154` ships
> **gated**, with the offending libcall moved out of the two indirect-ABI stages; see
> [§ Effect on #154](#effect-on-154).

## Symptom

```
$ build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mos6502 -Os -S -o /dev/null k.c
error: <unknown>:0:0: ran out of registers during register allocation in function 'stage'
1 error generated.
```

## Reproduction — twelve lines of C, no target features

`k.c`:

```c
#include <stdint.h>
extern uint16_t ext(uint16_t, uint16_t);
__attribute__((noinline))
void stage(uint16_t *p, uint16_t k) {
    uint16_t a = (uint16_t)(p[0] + k);
    uint16_t b = (uint16_t)(p[1] ^ a);
    uint8_t  c = (uint8_t)(((uint8_t*)p)[4] + (uint8_t)b);
    p[0] = (uint16_t)(ext(a, 13849u) + b);
    p[1] = (uint16_t)(b - (uint16_t)c);
    ((uint8_t*)p)[4] = (uint8_t)((a >> 8) ^ c);
}
```

| compiler | cpu | `-O0` | `-O1` | `-O2` | `-Os` | `-Oz` |
|---|---|---|---|---|---|---|
| this fork's `mos-clang` | `mosw65816` | OK | **error** | **error** | **error** | **error** |
| this fork's `mos-clang` | `mos6502` | OK | **error** | **error** | **error** | **error** |
| **pristine `build/upstream-llc/bin/llc`** | `mos6502` | OK | **error** | **error** | — | — |

The pristine leg is the load-bearing one. The IR was emitted by this fork's clang and then had
its `target datalayout` line **rewritten to the unpatched MOS layout** (dropping the `p1`/`p2`/`p3`
far address spaces that fork patch `0001` adds) before being handed to the untouched upstream
`llc`:

```
$ sed 's|^target datalayout = .*|target datalayout = "e-m:e-p:16:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"|' k.ll > k_pristine.ll
$ build/upstream-llc/bin/llc -mtriple=mos -mcpu=mos6502 -O2 k_pristine.ll -o /dev/null
error: <unknown>:0:0: ran out of registers during register allocation in function 'stage'
$ echo $?
1
$ build/upstream-llc/bin/llc -mtriple=mos -mcpu=mos6502 -O0 k_pristine.ll -o /dev/null ; echo $?
0
```

So none of this fork's 25 patches is implicated: the failing function uses address space 0 only,
no 65816 instruction, and no `+mos-a16`/`+mos-xy16` feature.

## What it takes to trigger — measured, one ingredient at a time

All at `-mcpu=mos6502 -Os`, same function skeleton, varying one thing:

| variant | result |
|---|---|
| 3 stores through `p`, one of them **byte**-width, **with** a call | **error** |
| the same 3 stores, byte-width included, **no call** | OK |
| 2 **word**-only stores + a call | OK |
| 3 **word**-only stores + a call | OK |
| byte access present + call, byte value **not** live across the call | **error** |
| pointer is a **static global base**, not a parameter | **error** |
| the same shape with `__mulhi3` (a libcall) instead of `ext` (a normal call) | **error** |
| `__udivhi3` instead of `__mulhi3` | **error** |

Reading across: the necessary combination is **a call** plus **mixed-width (i8 *and* i16) memory
traffic through the same pointer** plus **three or more stores**. Word-only traffic of the same
volume is fine, and the identical mixed-width traffic without a call is fine. Which call it is —
libcall or ordinary extern — does not matter, and neither does whether the byte value is live
across it, nor whether the pointer arrives as a parameter.

That points at the pointer's own base register: the 16-bit base must be held in a zero-page
imaginary pair across the call, and the i8 access appears to force an additional
class-constrained residency (`Y` for the indexed byte form) on top of the i16 accesses' own
staging, with nothing left to spill it into. **That is a hypothesis from the ingredient table, not
a diagnosis** — no `-debug-only=regalloc` trace was taken, because chasing the root cause is not
this dispatch's remit. The prior art worth reading first is
[`docs/investigations/65816-a16-regalloc-pressure-failure.md`](65816-a16-regalloc-pressure-failure.md)
and fork patch `0009`, which fixed a *different* out-of-registers deadlock (`+mos-a16` only,
A-pinned i8 loop counter). This one is neither `+mos-a16`-gated nor counter-shaped, so `0009`'s
de-pin does not cover it.

## Why this one matters beyond itself

`struct { uint16_t; uint16_t; uint8_t; }` updated in place, with a helper call in the middle, is
not an exotic shape — it is an ordinary record-update function, and it is exactly what any
by-value stage over a >32-bit aggregate compiles into once the ABI has turned the argument into a
pointer. The battery has 154 demos and had never hit it because no prior demo put a call *between*
a byte member and a word member of the same object. A user meeting this gets a hard compile
failure with no source location, on code that has nothing visibly wrong with it, and the only
workaround available to them is to move the call or widen the byte field.

## Effect on #154

`#154 byvaledge` exists to compile both sides of clang's `getTypeSize(Ty) > 32` by-value
classifier adjacently. Its 5-byte stage `bv_stage40` originally derived its result with a 16×16
multiply, which is a `__mulhi3` libcall sitting between the byte and word members of the record —
the exact shape above — and it failed to compile.

The multiply is **not** the corner under test. The corner is the ABI form of the parameter, and
that is unchanged by removing it, so `bv_stage40` now derives its result with shift/add/xor only
(`bv_stage32`, on the `getDirect` side, keeps its multiply and is unaffected) and the demo ships
**gated**, with the ABI structure gate intact and this
defect referenced from the header. The gate was **not weakened**: nothing about the `ByVal=false`
call-site-copy check, the caller re-read, or the `-verify-machineinstrs` requirement was relaxed.

## Status

- **OPEN.** Upstream `llvm-mos` register-allocation defect, reproduced on pristine `llc`.
- No fix attempted; needs separate dispatch, at a tier that can work in the register allocator.
- Next step for whoever takes it: `llc -mcpu=mos6502 -O2 -debug-only=regalloc k_pristine.ll` and
  the last-chance-recolor failure it reports, then decide whether the fix is a de-pin (as `0009`
  was) or a genuine spill-path gap.
- If it holds up, it is an upstream bug report — add it to
  [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md) when drafted.
