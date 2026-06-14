# M2 / #321 — Increment 1d: GISel-native 16-bit values (s16 lives in A16 ⊕ Imag16)

**Date:** 2026-06-14 · **Status:** **IN PROGRESS.** · **Milestone:** M2 (ROADMAP step 5).
**Builds on:** 1b (the `A16` accumulator + `Ac16` + `MOSInsertREPSEP`) and 1c (chained adds,
[plan](2026-06-14-321-increment-1c-chained-16bit-alu.md)).

## Goal — beyond the peephole

1b/1c handle fixed memory→memory shapes via combiner peepholes. This phase makes the **GISel pipeline
natively carry an `s16` value**: keep `s16` un-narrowed through the legalizer, allocate it across the
16-bit storage (`A16` ⊕ the zero-page `Imag16` pairs), and select 16-bit ops on it. That unlocks the
cases the peephole bails on — **locals, multi-use intermediates, arbitrary 16-bit dataflow** — not
just `g = a OP b` over globals.

Test the peephole can't do (the target for the core step):
```c
unsigned short f(void){ unsigned short t = a + b; return t & c; }  // t is a local, reused
```

## The hard constraint and the risk

There is exactly **one** `A16` register, and it **aliases the 8-bit `A`** (`A16 = B:A`). So:
- A second live `s16` value must **spill to a zero-page `Imag16` pair** — exactly as 8-bit values
  spill across `Imag8`. The `s16` register class is therefore `Anyi16 = A16 ⊕ Imag16`.
- `ADC`/`SBC`/… are **accumulator-only**, so an `s16` ALU op needs its left operand in `A16`; the
  allocator inserts copies (`lda`/`sta` zero-page) to move values between `A16` and `Imag16`.
- Because `A16` aliases `A`, anything here can perturb the **existing 8-bit codegen**. So the **6502
  corpus 7/7 is the guard at every step**, and each step is committed only when green.

## Decomposition (each step verified non-breaking before the next)

1. **`Anyi16` register class** (`A16 ⊕ Imag16`) — tablegen only, **inert** until the selector emits
   `s16` vregs. The `s16` sum-type analog of `Anyi8 = Imag8 ⊕ GPR`. *Verify: builds, corpus 7/7.*
   **← current step.**
2. **16-bit zero-page copy support** — `copyPhysReg` for `A16 ↔ Imag16` (16-bit `lda`/`sta` zero-page,
   `MLow=1`; the REP/SEP pass brackets them) + the `LDAImag16`/`STAImag16` logical ops. Inert until
   `A16` vregs exist. *Verify: builds, corpus 7/7.*
3. **Legalizer: keep `s16` `G_ADD` legal** under `HasAccum16` (skip `narrowScalarAddSub`). This forces
   steps 4-5 simultaneously (the value must now be selected + allocated) — the core big-bang.
   *Verify: a local-s16 test compiles; corpus 7/7; no GISel fallback.*
4. **Selector**: `s16 G_ADD` → `lda`/`clc`/`adc`/(result) on `Anyi16`, operands in `Imag16` or folded
   from memory; the running value in `A16`. Reuse the 1b/1c `ADCAbs16` + a new `ADCImag16` (ADC
   zero-page, 16-bit).
5. **RegBank**: `s16` → `AnyRegBank` (already covers `Imag16` + `Ac16`); confirm the mapping.

Then iterate outward: sub/bitwise, immediates, multi-use, eventually loops + cross-block REP/SEP
mode-tracking (the larger remainder).

All edits extend `patches/llvm-mos/0002-321-accum16.patch`.

## Verification (per step + final)

- **Every step:** 6502 corpus **7/7** (the aliasing guard) + 1b/1c a16* suite green + SDK builds.
- **Core (step 3+):** a function with a **local** `s16` add/use compiles to 16-bit `A16` codegen
  (`-verify-machineinstrs` clean, no GISel fallback) and runs correctly on **both** emulators.
- **Smaller/faster:** the 16-bit path beats the 8-bit narrowed output on a representative kernel.

## Out of scope (later)

- Loops + cross-block REP/SEP mode-tracking; the hardware-stack ABI / 16-bit calling convention
  (16-bit args/returns — the upstream-gated part).
