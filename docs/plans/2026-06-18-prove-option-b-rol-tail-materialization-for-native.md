# Prove Option B (rol-tail materialization) for native s16 EQ-as-value

## Status — DONE (2026-06-18): proven, Option B is a regression

Experiment ran in throwaway worktree `wt/321-eqval-optb` (seeded from main @ c798c31, the Phase 0 baseline).
The branchless `rol`/`adc` tail was built **without** a new pseudo via `G_UADDE(0,0,carry)` → `txa; adc #0`
(confirmed branchless: `adc` present, **no** `bcc`/`beq` materialize diamond), and measured a **regression on
every shape — worse than even Option A**: `a16eqval` 104→**120 (+16 B)**, `a16eqvalc` 121→**149 (+28 B)**,
`a16eqvalp` 154→**175 (+21 B)**, all `-verify-machineinstrs` clean. Root cause (disasm-confirmed): the
branchless path **forgoes the `CmpBr` compare-fusion** the diamond exploits — it must form `X=LHS^RHS`,
stash it, and run a standalone `lda #0; cmp X` to make a carry (equality's Z isn't rotatable), paying for a
non-fused compare *plus* the value computation while saving only ~6 B on the tail. A hand-built `CmpSel*16`
pseudo would hit the same two costs, so it was **not** built. **Verdict: WON'T-IMPLEMENT stands**, now
measured for Option B too. Full table + disasm + mechanism recorded in
[full-native materialize plan §Phase 0](2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md).
Worktree removed; main `vendor/`/`0002` uncontaminated.

## Context

The plan `docs/plans/2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md` (Status: WON'T-IMPLEMENT)
landed an empirically-measured **Phase 0**: Option A (branchless materialize by reusing existing native ops)
is a **+14 B regression** because the backend lowers any flag→byte (carry copied to the result) to a
control-flow **diamond**, so the XOR approach just adds the value computation on top of an unchanged diamond.

But that plan's **Option B** paragraph — a dedicated `CmpSel*16` pseudo with an explicit `lda #0; rol`/`adc`
branchless tail — was **predicted, not built**: *"A rol tail would shave the materialization (~5 B) but the
pseudo must first compute the difference/XOR value, whose cost exceeds the rol-tail savings → net ≥ diamond,
for a substantial 5-pseudo change."* The user wants this **proven empirically**, not asserted, and the doc
updated to "measured." Throwaway-worktree modifications are authorized.

**What read-only investigation already established (this turn):**
- No branchless flag→byte path exists anywhere today — even the **8-bit default** `b=(a==c)` diamonds
  (confirmed in `MOSLegalizerInfo.cpp` legalizeICmp + `MOSLowerSelect`; the "equality into C" comment refers
  to the SBC's flag, not the final byte). My Option A spike independently showed the carry-copy diamonds.
- **A cheap way to emit the branchless `adc` tail exists without a new pseudo:** `selectAddE`
  (`MOSInstructionSelector.cpp` ~2117) already lowers `G_UADDE`/`G_SADDE` → `ADCImm`/`ADCImag8`. So building
  `G_UADDE(0, 0, carry)` in the legalizer should select to `lda #0; adc #0` = carry→bit0 = the rol-tail.

## Goal

Produce a **measured** Option B result (rol/adc-tail materialization vs the select-diamond, in 16-bit-ambient
context, bytes) and rewrite the plan's Option B paragraph from "predicted" to "measured" — with the table,
disasm, and verdict. Expected verdict: net ≥ diamond (parity-or-small-regression). If it unexpectedly **wins**,
that overturns the WON'T-IMPLEMENT and the plan/TODO flip to a real implementation task.

## Experiment (in a throwaway worktree, then discard)

All work in `wt/321-eqval-optb` (a fresh `git worktree`), seeded from main's toolchain by copying
`vendor/llvm-mos` + `build/{llvm-mos,llvm-mos-install,.ccache}` (container mounts to fixed `/work`, so a
seeded `build/` is portable; ~23 s copy, ~11–25 s incremental rebuilds). **No `vendor/`/patch change ships.**

**Step 1 — Baseline + characterize (one build, the seeded compiler).**
- Confirm the diamond baselines: `a16eqval` / `a16eqvalc` / `a16eqvalp` `.text.main` (was 104 / 121 / 154 at
  commit c798c31; re-capture against whatever main is seeded from).
- Compile two throwaway shapes to **confirm the no-branchless-path premise directly**: UGE-as-value
  (`b = (a >= c)`) and `b = (x != 0)` — disasm each; expect a diamond, not `adc`/`rol`.

**Step 2 — Build the rol/adc tail (cheap path first).**
In `MOSLegalizerInfo.cpp::legalizeICmp`, the EQ native **value** path (`NativeS16 && !isNZUseLegal`, same site
as the Option A spike), replace the diamond-producing materialization with a branchless tail:
- `X = LHS ^ RHS` (native EOR → Imag16; ==0 iff equal) — already validated to select cleanly in Phase 0.
- `Ceq = SBC(0, X).getReg(1)` = `(0 ≥ᵤ X)` = `(X == 0)` = `(LHS == RHS)` (carry).
- **Branchless byte:** `byte = G_UADDE(0_i8, 0_i8, Ceq).getReg(0)` → should select via `selectAddE` to
  `lda #0; adc #0` (= carry). Feed `byte` to `Dst` (handle the i1/i8 type thread: truncate to the i1 Dst, or
  produce the result the zext-to-i16 consumer expects — resolve at build time).
- Rebuild (confirm `clang-23` mtime advanced — stale-build gotcha), recompile the 3 shapes, disasm; verify
  the tail is `adc`/`rol` (no `bcc`/`beq` diamond) and `-verify-machineinstrs` is clean.

**Step 2-fallback — only if the cheap path can't emit the tail** (type/regalloc drops the carry between the
`SBC` and the `G_UADDE`, or it re-diamonds): build a **minimal single** `CmpSel`-style post-RA pseudo
mirroring `CmpBrImag16`/`expandCmpBr16` (`MOSInstrPseudos.td` + `expandCmpBr16`'s dispatch in
`MOSInstrInfo.cpp`) whose expansion emits `LDAImag16; CMPImag16; LDImm16 0; ROL` instead of `…; BR`, wired for
just the computed/Imag16 shape (`a16eqvalc`). One pseudo is enough to measure the tail cost — do **not** build
all five residency variants for a measurement.

**Step 3 — Measure + decide.** Tabulate diamond vs rol-tail bytes per shape (16-bit-ambient). The arithmetic
to settle: does the rol-tail's materialization saving (~5 B vs the diamond) exceed the value-computation cost
(the `eor` + the `SBC(0,X)`/`cmp` it forces, which Phase 0 measured contributes to the +14)? Net ≥ diamond ⇒
prediction proven (WON'T-IMPLEMENT stands). Net < diamond ⇒ prediction wrong ⇒ flip to implement.

## Critical files (read/observe; modify only inside the worktree)

- `vendor/llvm-mos/.../MOSLegalizerInfo.cpp` — `legalizeICmp` EQ value path (the spike site; grep
  `buildNZSelect`, `NativeS16Eq`). The `G_UADDE` tail goes here.
- `vendor/llvm-mos/.../MOSInstructionSelector.cpp` — `selectAddE` (G_UADDE → ADC) confirms the cheap path.
- `vendor/llvm-mos/.../MOSInstrPseudos.td` + `MOSInstrInfo.cpp::expandCmpBr16` — template **only if** the
  Step-2-fallback pseudo is needed.
- Measurement uses the worktree's `build/llvm-mos-install/bin/mos-clang` + `llvm-objdump` (host compile, no
  emulator — Phase 0 is byte/disasm only): `--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang
  +mos-a16 -Os -mllvm -verify-machineinstrs -c`.

## Doc updates (the deliverable — in the MAIN repo, committed)

1. `docs/plans/2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md` — rewrite the **Option B**
   bullet in §Phase 0 from "predicted, not built" to **measured**: the rol/adc-tail disasm, the per-shape
   byte table (diamond vs rol-tail), and the verdict. Keep/strengthen the Status line accordingly.
2. `TODO.md` — M2 item (c): if the verdict still says ≥ diamond, tighten the WON'T-IMPLEMENT note to "Option B
   measured too" (removes the "predicted" caveat). If it flips to a win, convert item (c) back to an open
   implement-it task pointing at the build.
3. Commit only those two files (stage explicitly; verify `git diff --cached --name-only`); do not push.

## Verification

1. Worktree builds clean; `clang-23` mtime advances on each rebuild (stale-build guard).
2. The Option B build is `-verify-machineinstrs` clean on `a16eqval`/`a16eqvalc`/`a16eqvalp`.
3. The rol-tail disasm shows `adc`/`rol` (not a `bcc`/`beq` 0/1 diamond) where the materialization fires —
   i.e. the experiment actually tested the rol tail, not an accidental re-diamond.
4. The byte table is captured with raw `llvm-objdump --section-headers` output; the verdict (≥ or < diamond)
   follows from it.
5. Worktree + scratch branch removed; `grep -c "SPIKE" main vendor/.../MOSLegalizerInfo.cpp` == 0 and `0002`
   untouched (main uncontaminated), as after Phase 0.
