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

## Design refinement (2026-06-14, after investigating copyPhysReg)

The naive mirror of the 8-bit path — keep the running value in `A16` like 8-bit keeps it in `A` —
hits a wall: `A16`'s high byte `B` is **not independently addressable** (only via `XBA` or 16-bit
ops), so `copyPhysReg` for `A16 ↔ Imag16` is ugly. **Tractable design instead:** s16 **values live in
`Imag16`** (zero-page pairs — already fully supported: reg-to-reg copies at `MOSInstrInfo.cpp:667`,
spills, the lot), and `A16` is used **only transiently within each selected op** — `lda zp; (clc;)
adc zp; sta zp`. This sidesteps the `B`-register `copyPhysReg` problem and is the true 16-bit analog
of the 6502 backend (s8 values in `Imag8`, computed via a transient `A`). Keeping a hot value in
`A16` across ops (eliminating the `sta`/`lda` round-trip via `Anyi16`) is a *later* optimization.

Consequence: the core is **cohesive** — `s16` `G_LOAD`/`G_STORE`/`G_ADD` must go native *together*
(a load feeding an add must already be `s16`-in-`Imag16`, not narrowed to two `s8`). New 16-bit
zero-page logical ops: `LDAImag16`/`ADCImag16`/`STAImag16` (`lda`/`adc`/`sta` zp, `MLow=1`).

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

## Core mechanism map (2026-06-14) — what step 3-5 must touch

- **Legalizer** `legalizeAddSub` (`MOSLegalizerInfo.cpp`): currently `narrowScalarAddSub(…S8)` for
  every non-±1 s16 add. Under `HasAccum16`, return early *without* narrowing for `s16` (leave it for
  the selector). Same idea for the `{G_LOAD, G_STORE}` rule (`:332`) — keep `s16` un-narrowed.
- **Selector** `selectAddSub` (`MOSInstructionSelector.cpp:456`): the s8 path does load-folding via
  `m_FoldedLdAbs`/`m_FoldedLdIdx` → `ADCAbs`/`ADCZpIdx`/`ADCAbsIdx`. The s16 path mirrors this with
  `ADCAbs16` (already exists, 1b) for folded near-abs loads and a new `ADCImag16` (ADC zp, 16-bit) for
  Imag16-resident operands; left operand and result are `Imag16`/`Ac16`, `A16` transient.
- **Cohesion risk:** because this changes legalization of **all** s16 load/store/add (not just
  `+mos-a16`-specific shapes — `unsigned short` is s16 everywhere), the 6502 **corpus is the
  non-negotiable guard**, and the change is only committed when green. It is a big-bang for the core
  (steps 3-5 land together or not at all), unlike the incremental peephole slices.

## Status note (2026-06-14)

Step 1 (`Anyi16`) is landed and green. The core (steps 2-5) was **started and de-risked, then the
partial WIP was reverted to keep the tree green** (committing a half-built big-bang would leave
`+mos-a16` adds that escape the peephole unselectable). Confirmed by going deep:

- **Tractable** — the feared `copyPhysReg` `B`-register problem **dissolves**: a single 16-bit
  `lda`/`sta` zp moves both bytes of `A16 = B:A` atomically, so `A16 ↔ Imag16` copies are just
  `LDAImag16`/`STAImag16` (the 16-bit analog of `LDImag8`/`STImag8`, which are `MOSTransfer<dst,src>`
  with the imaginary reg as the **def**).
- **Corpus-safe** — the native path is gated on `STI.hasAccum16()` (the legalizer ctor has `STI`), so
  default (corpus) builds keep the 8-bit narrowing untouched.

**Turnkey continuation (the exact remaining pieces):**
1. `LDAImag16`/`STAImag16` = `MOSTransfer<Ac16,Imag16>` / `<Imag16,Ac16>` + `MLow=1`; `ADCImag16` =
   `ADC_ZeroPage`-expanding, `Ac16`/`Imag16` operands. **Open Q:** their MC lowering — `STImag8`/
   `LDImag8` are custom-lowered (no `PseudoInstExpansion`); check whether the imaginary-reg→zp-address
   lowering generalizes to 16-bit or needs a `MOSMCInstLower` case.
2. Legalizer: `getActionDefinitionsBuilder(G_ADD)` → `if (STI.hasAccum16()) .legalFor({S16})` (split
   from `G_SUB`).
3. `copyPhysReg` (`MOSInstrInfo.cpp:~667`, by the `Imag16↔Imag16` case): add `Ac16↔Imag16` →
   `LDAImag16`/`STAImag16`.
4. Selector: `selectAdd16Native` mirroring `selectAddSub` (`:456`) — fold a near-abs load via the
   existing `m_FoldedLdAbs` → `ADCAbs16` (1b), else `ADCImag16`; result in `Ac16`.
5. Test `examples/65816/a16local.c` — a multi-use s16 intermediate (forces the native path past the
   peephole) → both emulators; corpus 7/7.

This is mechanical given the map, but multi-step with GISel iteration — a focused continuation.

## Verification (per step + final)

- **Every step:** 6502 corpus **7/7** (the aliasing guard) + 1b/1c a16* suite green + SDK builds.
- **Core (step 3+):** a function with a **local** `s16` add/use compiles to 16-bit `A16` codegen
  (`-verify-machineinstrs` clean, no GISel fallback) and runs correctly on **both** emulators.
- **Smaller/faster:** the 16-bit path beats the 8-bit narrowed output on a representative kernel.

## Out of scope (later)

- Loops + cross-block REP/SEP mode-tracking; the hardware-stack ABI / 16-bit calling convention
  (16-bit args/returns — the upstream-gated part).
