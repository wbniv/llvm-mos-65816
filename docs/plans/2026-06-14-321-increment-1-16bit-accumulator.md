# M2 / #321 — Increment 1: minimal 16-bit-accumulator slice (REP/SEP insertion), opt-in, dual-emulator-verified

**Date:** 2026-06-14 · **Status:** In progress — implementation started; first slice re-scoped (see
Implementation finding). · **Milestone:** M2 (ROADMAP step 5, first 16-bit-register codegen). **Builds on:** the #320 far-pointer slice (Increments
[1](2026-06-14-320-far-pointer-codegen.md) / [2](2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md)
/ [2b](2026-06-14-320-increment-2b-multi-bank-rom-far-read.md)) + the dual-emulator bench
([xcheck](2026-06-14-second-emulator-cross-check-bsnes-jg.md)).

## Context

M2 is the optimizing payoff: [#321](https://github.com/llvm-mos/llvm-mos/issues/321) — 16-bit register
mode for the WDC 65816. It's the **hard part** of the backend (the maintainers' own estimate;
asiekierka's stage-2 is "a pipe dream"). So, exactly as with #320, this plans the **smallest real
slice**, not the whole milestone: get a *single 16-bit-accumulator operation* to compile to
`REP #$20 / <16-bit op> / SEP #$20`, proving the REP/SEP-insertion mechanism end-to-end. The bench now
has **two emulators** (MAME + bsnes-jg via `dev/run.sh xcheck`) to verify correctness independently,
and the W65816 far-pointer codegen is the foundation this builds on.

**Decisive finding from backend exploration.** The MC/assembler layer *already* models 16-bit width:
instructions carry `MLow/MHigh/XLow/XHigh` TSFlags (`MOSInstrFormats.td:122-129`, set on the existing
`*_Immediate16` forms), and `MOSMCELFStreamer::emit816MXState` *already tracks* the M/X mode across the
instruction stream to emit `$ml/$mh/$xl/$xh` mapping symbols. So the gap is purely **codegen**: nothing
selects a 16-bit-accumulator op or inserts REP/SEP. A late pass can reuse the TSFlag annotation
(`MOSMCTargetDesc.h` `TSFlagMLow…`) — the same signal the streamer reads — to decide where REP/SEP go.

## Implementation finding (2026-06-14) — the first slice re-scoped

The backend models the accumulator as **8-bit `A` only** (`MOSRegisterInfo.td:70`); `def C` (line 75)
is the **carry flag**, not a 16-bit accumulator, and 16-bit register classes exist only for the
zero-page imaginary registers (`Imag16`). So a 16-bit **`lda`/`sta`** — a 16-bit value flowing through
the accumulator — requires a **dual-width accumulator register** (`A` reused as the low half of a
16-bit `C` that aliases the same physical bits, sized 8- or 16-bit by the runtime M flag) + a register
bank for it. **That dual-width aliasing register is the genuine hard core of #321** (it's exactly why
the milestone is "hard"), not a minimal first step.

**Re-scope, in two sub-slices:**
- **Increment 1a (this slice): the REP/SEP-insertion *mechanism*, via a register-free 16-bit op
  (`STZ`).** `*g16 = 0` compiles (under `+mos-a16`) to `REP #$20; stz g16; SEP #$20` (one 16-bit STZ
  writes 2 bytes) instead of two 8-bit stores. `STZ` has **no register operand**, so this delivers the
  reusable `MOSInsertREPSEP` pass + the opt-in feature + the 16-bit-form/TSFlag wiring + the dual-emulator
  `a16` verification harness, **without** the dual-width register. Smaller than the 8-bit build; proves
  16-bit-mode codegen runs correctly on both emulators.
- **Increment 1b (next): the 16-bit accumulator load/store** — model the dual-width `A`/`C` register
  (the hard core), so `lda`/`sta` flow a 16-bit value. Reuses everything 1a builds.

## Progress (2026-06-14)

- **1a core landed (non-breaking).** The opt-in `FeatureAccum16` (`-mattr=+mos-a16`) + the
  `MOSInsertREPSEP` `MachineFunctionPass` (reads the existing `MLow/MHigh` TSFlags, tracks the M mode,
  inserts `REP #$20`/`SEP #$20` at transitions; functions begin/end 8-bit; registered in
  `addPreEmitPass` before branch relaxation) + all wiring (subtarget accessor, pass registry, CMake)
  are implemented and captured as `patches/llvm-mos/0002-321-accum16.patch`. Toolchain rebuilt clean;
  **6502 corpus 7/7** — the pass is inert by default (early-returns unless `hasAccum16()`, and a no-op
  until a 16-bit instruction exists), so it's non-breaking by construction.
- **Next (1a part 2):** the 16-bit `STZ` selection so the pass has something to bracket — a 16-bit
  `STZ` form tagged `MLow=1` + a feature-gated legalizer/selector path for `*g16 = 0`. Then verify
  `REP #$20; stz; SEP #$20` at disasm + correct on both emulators + smaller than the 8-bit build.

## Scope — Increment 1a (minimal, opt-in, non-breaking)

A 16-bit load+store (one `uint16_t` round-trip, e.g. `*dst = *src;` or `uint16_t f(){ return g; }`)
compiles, **only under a new opt-in feature**, to one REP/SEP-bracketed 16-bit-A sequence
(`REP #$20; lda src; sta dst; SEP #$20`) instead of four 8-bit ops — verified at the disassembly level,
run correctly on **both** emulators, and **smaller** than the 8-bit-mode output (ROADMAP step 5's
"smaller/faster"). Default `mosw65816` (far pointers) and 6502 are untouched.

**Deliberately deferred** (the genuinely hard #321 problems — later increments): the full **xy16 mode**
(X/Y permanently 16-bit) and its ABI/**calling convention**; **mode-tracking across control flow**
(branches/loops/calls — M/X is a global processor mode); **REP/SEP churn minimization** (batch toggles
via dataflow); 16-bit **arithmetic carry chains**; interrupts changing P. Increment 1 uses the simplest
case: a straight-line **leaf** function with A pinned to 8-bit at entry/exit (the pass toggles locally).

## Approach

1. **New opt-in feature** `FeatureAccum16` (predicate `HasAccum16`) in `MOSFeatures.td` — enabled via
   `-mattr=+mos-a16` (and/or an experimental device in `MOSDevices.td`), **not** implied by
   `FamilyW65816`. Keeps the slice additive: the 16-bit path is inert unless explicitly opted in.

2. **16-bit-accumulator instruction forms.** Tag accumulator load/store forms (`LDA`/`STA` absolute/zp)
   with `MLow = 1` — same opcodes as the 8-bit forms (the M flag governs operand width at runtime),
   following the existing `Immediate16` + TSFlag pattern (`MOSInstrFormats.td:852-860`). Define a
   16-bit GISel pseudo pair (`G_LOAD_A16` / `G_STORE_A16`, `Predicates=[HasAccum16]`) → these forms,
   mirroring the `G_LOAD_FAR_ABS` pattern from #320.

3. **GISel (feature-gated).** In `MOSLegalizerInfo.cpp`, a `HasAccum16` rule that keeps a 16-bit
   `G_LOAD`/`G_STORE` as a single 16-bit-A op (rather than `widenScalarToNextMultipleOf`→S8 pairs);
   `MOSInstructionSelector.cpp` selects the `*_A16` pseudos → the `MLow` MC forms. Narrow surface: one
   load + one store, leaving all other 16-bit lowering on the existing 8-bit path.

4. **REP/SEP-insertion pass — the reusable core.** A new `MOSInsertREPSEP` `MachineFunctionPass`
   registered late (`addPreEmitPass`/`addPreSched2`, modeled on `MOSLateOptimizationPass`). It walks
   MIs, reads each instruction's `MLow/MHigh` TSFlag (the same `TSFlagMLow…` the streamer uses), tracks
   the current M mode, and inserts `REP #$20` (M→16) / `SEP #$20` (M→8) at transitions; pins A to 8-bit
   at function entry/exit (the Increment-1 convention). The mode-walk logic mirrors
   `MOSMCELFStreamer::emit816MXState`. `REP_Immediate`/`SEP_Immediate` already exist
   (`MOSInstrInfo.td:680-681`) — no MC work. (Increment 1: straight-line only; control-flow merging is
   a later increment.)

5. **Test artifact + dev target.** `examples/65816/a16.c` (a 16-bit load/store). Reuse the existing
   verification machinery: a `dev/run.sh a16` (disasm assert like `dev/far.sh` — `c2 20` REP / `e2 20`
   SEP bracketing a 16-bit `lda`/`sta`) plus a run on **both** emulators (MAME `run_assert` + the
   bsnes-jg `jgxcheck`), and a byte-size compare vs the same source built without `+mos-a16`.

All backend edits captured as a tracked patch `patches/llvm-mos/0002-321-accum16.patch` (applied by
`dev/toolchain.sh`), exactly like the #320 far-pointer patch — the eventual upstream #321 diff.

## Critical files (vendor/llvm-mos backend)

| File | Change |
|------|--------|
| `MOSFeatures.td` / `MOSDevices.td` | new `FeatureAccum16` (`HasAccum16`), opt-in (not implied by W65816) |
| `MOSInstrInfo.td` / `MOSInstrFormats.td` | 16-bit-A `LDA`/`STA` forms tagged `MLow=1` (reuse the TSFlag pattern) |
| `MOSInstrGISel.td` | `G_LOAD_A16` / `G_STORE_A16` pseudos (`[HasAccum16]`) |
| `MOSLegalizerInfo.cpp` | feature-gated: keep a 16-bit `G_LOAD`/`G_STORE` as one 16-bit-A op |
| `MOSInstructionSelector.cpp` | select the `*_A16` pseudos → the `MLow` MC forms |
| `MOSInsertREPSEP.cpp` (**new**) + `MOSTargetMachine.cpp` | the REP/SEP-insertion pass + register it late |

**Reused:** `MOSMCTargetDesc.h` `TSFlagMLow/…` enums and the M/X-mode-walk logic from
`MOSMCELFStreamer::emit816MXState`; the existing `REP_Immediate`/`SEP_Immediate`; the `G_LOAD_FAR_ABS`
pseudo/selection pattern from #320; the from-source toolchain loop (edit → `dev/run.sh toolchain` →
test) and the dual-emulator bench (`dev/run.sh far` / `xcheck`).

## Risks

- **This is the hard milestone.** The deep problems — REP/SEP mode-tracking across control flow and the
  calling-convention width contract — are *deferred*, but Increment 1 must be honest that it only does
  the straight-line leaf case. Over-reaching into control flow is the main scope risk.
- **Same-opcode width ambiguity.** A 16-bit `LDA abs` is the same opcode as 8-bit; correctness depends
  entirely on the REP/SEP pass getting the mode right around it. The disasm + *both*-emulator checks are
  the guard (a wrong mode yields a wrong value, caught at runtime).
- **Legalizer surgery.** Keeping one 16-bit case un-narrowed without disturbing the existing 8-bit
  lowering — feature-gated and narrow, but iterative (expect several edit→rebuild→inspect cycles, as in
  #320; the from-source toolchain makes each an incremental relink).
- **Calling convention not yet decided** (open in #321 — see ROADMAP). Increment 1 sidesteps it by
  pinning A to 8-bit at entry/exit; that assumption is revisited when xy16/the ABI lands.

## Verification (compiler + dual-emulator)

1. **Non-breaking** — without `+mos-a16`, 6502 corpus still 7/7 and the far-pointer slice unchanged
   (`dev/run.sh corpus` + `far` + `xcheck`). The new feature is inert by default. (Evidence: corpus +
   xcheck tables.)
2. **16-bit-A lowering (the deliverable)** — `a16.c` built with `+mos-a16`: `llvm-objdump` shows
   `c2 20` (`rep #$20`) + a 16-bit `lda`/`sta` + `e2 20` (`sep #$20`), **not** four 8-bit ops.
   (Evidence: disasm excerpt.)
3. **Correct on both emulators** — the 16-bit round-trip produces the right value in **MAME** *and*
   **bsnes-jg** (`run_assert` + `jgxcheck`), confirming the REP/SEP mode is right. (Evidence: SMOKE
   lines from both.)
4. **Smaller than 8-bit mode** — the `+mos-a16` object/function is fewer bytes than the same source
   built without it (ROADMAP step 5's "smaller/faster"). (Evidence: `stat`/`size` compare.)
5. **No GISel fallback abort / `-verify-machineinstrs`** clean on the test. (Evidence: clean compile.)

## Out of scope (later increments / M2 continuation)

- **xy16 mode** (X/Y permanently 16-bit) + the **hardware-stack ABI** (16-bit SP, stack-relative) +
  the **calling convention** (the open #321 decision) — the bulk of stage 1 after the mechanism works.
- **Mode-tracking across control flow** (branches/loops/calls), **REP/SEP churn minimization**, 16-bit
  **arithmetic** (carry chains), interrupt/P handling.
- **#321 stage 2** (xy8/xy16 switching) — asiekierka: "may well be a pipe dream."
- **Upstream PR** — opens after a credible running 16-bit slice + the calling-convention discussion.
