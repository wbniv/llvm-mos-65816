# M2 / #321 — Increment 1c: chained 16-bit ALU (value stays live in A16)

**Date:** 2026-06-14 · **Status:** **COMPLETE (first slice).** `g = a + b + c` fuses under `+mos-a16`
to one bracket `rep #$20; lda b; clc; adc a; clc; adc c; sta g; sep #$20` — the running sum threads
`A16` across both adds (the intermediate `a+b` survives in the accumulator for the `+c`) — and reads
`corpus_result == 0x1230` on **both** MAME and bsnes-jg (`dev/run.sh a16chain`). Non-breaking: 1b
(add/sub/bitwise/imm) + 1a + corpus 7/7 all green, SDK builds. The first codegen where a 16-bit value
genuinely survives across operations in the accumulator — the first step of the general path.
· **Milestone:** M2 (ROADMAP step 5).
**Builds on:** Increment 1b (the dual-width `A16` accumulator + the `Alu16Abs` combiner/selector +
the `MOSInsertREPSEP` width-agnostic-flag refinement,
[plan](2026-06-14-321-increment-1b-dual-width-accumulator.md)).

## Context — why this is "the general path", not more peephole breadth

1b made the full basic 16-bit ALU work (`+ - & | ^`, memory + immediate), but only for the **fixed
shape** `g = a OP b`: each fused op is self-contained (`lda; op; sta`) and its `A16` value never
coexists with other live values. Real 16-bit code — and ROADMAP step 5's actual bar, a fixed-point
**multiply-add kernel** — needs a value to **stay live in `A16` across multiple operations**. The
smallest honest form of that is a chained expression:

```c
g = a + b + c;   // ((a + b) + c): the intermediate (a+b) must stay in A16 for the +c
```

### Grounding (2026-06-14) — what the chain looks like and why 1b misses it

Generic MIR (pre-legalizer) for `g = a + b + c`:

```
%2 = G_LOAD b ; %0 = G_LOAD a
%4 = G_ADD %2, %0            ; a+b
%5 = G_LOAD c
%7 = G_ADD %4, %5            ; (a+b)+c   <- operand %4 is an ADD, not a load
G_STORE %7, g
```

1b's `matchAlu16Abs` requires **both** operands of the stored ALU op to be near-abs loads (or one a
constant). Here the outer add's first operand `%4` is itself a `G_ADD`, so 1b doesn't fire and the
whole thing falls back to the 8-bit ADC carry chain (~25 insns). The desired 16-bit code keeps the
running sum in `A16`:

```
rep #$20
lda b ; clc ; adc a ; clc ; adc c     ; A16 threads the running sum
sta g
sep #$20
```

(`clc` before each `adc` discards the previous add's carry-out — each is an independent 16-bit add;
mod-2^16 addition is associative, so the order/grouping doesn't change the result. The `clc`s are
M-width-agnostic, so the whole chain stays in **one** REP/SEP bracket — 1b's refinement already
handles that.)

## Scope — Increment 1c (first slice)

Fuse a **homogeneous left-leaning ADD chain** of ≥3 near-abs-global 16-bit loads,
`g = t0 + t1 + … + tN`, into a single REP/SEP-bracketed sequence that threads the running sum through
`A16`. Opt-in `+mos-a16`, non-breaking. This is the first codegen where a 16-bit value genuinely
**survives across operations** in the accumulator.

**Deliberately deferred** (later 1c slices / the full general path):
- Other chain ops (sub is order-sensitive; and/or/xor chains are easy follow-ons) and **immediates in
  chains** (this slice requires all terms to be loads).
- **Spilling**: when more than one 16-bit value is live at once (this slice's chain is straight-line,
  so `A16` is the only live 16-bit value — no spill needed). True multi-value liveness needs the
  GISel-native s16 register allocation (keep s16 un-narrowed, allocate across `A16` ⊕ `Imag16`), the
  eventual general implementation.
- Loops (the multiply-add *kernel*): the per-iteration `acc = acc + term` already fuses via 1b; the
  loop body's mode-tracking across branches is a separate REP/SEP-pass step.

## Approach (mirrors 1b's combiner→pseudo→selector, made variadic)

The chain matcher is **disjoint** from 1b's `matchAlu16Abs` by construction: 1b fires only when both
operands are loads/const (exactly 2 terms); the chain fires only when an operand is itself an add
(≥3 terms). The inner adds are never stored directly, so 1b never sees them.

1. **`G_ADDCHAIN16_ABS`** — a variadic MOS target-generic pseudo (`variable_ops`, `[HasAccum16]`):
   operand 0 = store global, operands 1..N = the term globals; carries N load memoperands + 1 store
   memoperand. (Target-generic so the legalizer skips it by opcode-range and InstructionSelect lowers
   it — same model as 1b; **no** legalizer rule, which would corrupt the tables.)
2. **Combiner rule `add_chain16`** (`MOSCombine.td` + `MOSCombiner.cpp`): root `G_STORE` to a near-abs
   global whose value is a single-use `G_ADD`; a recursive `collectAddChain` walks the add tree
   gathering leaf terms — each must be a single-use near-abs load, each interior node a single-use
   `G_ADD` — and bails (no fuse) on anything else. Require ≥3 terms (≤2 is 1b's job). Apply builds
   `G_ADDCHAIN16_ABS` and erases the store + all adds + all loads.
3. **Selector `selectAddChain16`**: `lda t0` → for each remaining term `clc; adc tI` threading the
   `A16` vreg → `sta g`, all constrained to `Ac16`. The `MOSInsertREPSEP` mode-walk brackets the run
   (lda/adc are `MLow=1`; the clc carry-inits are agnostic).

All backend edits extend `patches/llvm-mos/0002-321-accum16.patch`.

## Critical files (vendor/llvm-mos backend)

| File | Change |
|------|--------|
| `MOSInstrGISel.td` | new variadic `G_ADDCHAIN16_ABS` pseudo |
| `MOSCombine.td` / `MOSCombiner.cpp` | `add_chain16` rule + `matchAddChain16`/`applyAddChain16` + `collectAddChain` |
| `MOSInstructionSelector.cpp` | dispatch case + `selectAddChain16` (variadic lda/adc…/sta threading A16) |

## Verification (compiler + dual-emulator)

1. **Non-breaking** — without `+mos-a16`: corpus 7/7; with it, 1b's a16add/a16sub/a16bit/a16imm still
   green; SDK builds. (Evidence: suite tail.)
2. **Chain lowering** — `a16chain.c` (`g = a + b + c`) with `+mos-a16`: `llvm-objdump` shows one
   `rep #$20` … `sep #$20` bracket containing `lda` + two `adc` (the running sum threads A16), not the
   8-bit carry chain. (Evidence: disasm.)
3. **Correct on both emulators** — `corpus_result == <a+b+c>` on **MAME** *and* **bsnes-jg**.
   (Evidence: SMOKE lines.)
4. **Smaller than 8-bit mode** — the `+mos-a16` chain is fewer bytes than the 8-bit build. (Evidence:
   `size` compare.)
5. **No GISel fallback / clean compile.** (Evidence: clean build.)

## Out of scope (later)

- Sub/bitwise chains; immediates mixed into chains.
- GISel-native s16 register allocation (multi-value liveness + spilling) — the full general path.
- Loops + cross-block REP/SEP mode-tracking; the hardware-stack ABI / 16-bit calling convention
  (the upstream-gated part).
