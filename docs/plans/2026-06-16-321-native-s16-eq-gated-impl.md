# #321 — gated native s16 equality-as-value (v1: indirect-load operand)

**Date:** 2026-06-16
**Status:** **DONE (v1) — landed 2026-06-17.** Gated indirect-load native EQ-as-value in
`MOSLegalizerInfo::legalizeICmp` (no new pseudo). All gates green: `eq_deref` 38→34 B native, every other
shape byte-identical (no regression), `-verify-machineinstrs` clean, ambient indirect-EQ native;
`a16eqvalp` host==default==+mos-a16 (`0x0101`) on MAME + bsnes-jg; suite 44/44, corpus 7/7; **`fuzz
50/50`** (0 mismatch / 0 crash, on the F4-fixed build); `patches/0002` round-trips (no F4 leakage). The
earlier "48/50" was a stale pre-F4 build, not this change. **v2** (computed-LHS), **v3** (both-global
abs-fold), and the **`g1==0x1234`** immediate sub-case all **landed 2026-06-17** — see "Follow-ups".
**ROADMAP:** step 5 (M2) · **TODO:** M2 "native s16 equality-as-value"
**Predecessor / evidence:**
[native-EQ design + spike results](2026-06-16-321-native-s16-eq-as-value-cmpsel.md) — the spike proved
(a) the existing `CmpBr` path materializes native EQ-as-value (no new pseudo) and (b) the *blanket* form
regresses register/global operands, so the work is to **gate** it to where it wins.
**Principle:** modest gains are worth doing on a compiler (amplified across every program built with the
toolchain); the gate makes the win **regression-free**, which is the bar.

## Scope — v1 = indirect-load operand only

From the spike, native EQ-as-value wins **−4 B** for an indirect-load operand (`*p == c`) and **−3 B** for
an `Imag16`-resident computed operand, but **regresses** register/param (+8 B) and global/abs (+4–12 B)
operands. v1 ships the **clearest, most robust** win and defers the rest:

- **v1 (this plan):** fire native EQ-as-value only when **an operand is a non-absolute (indirect) s16
  load** (`*p == c`, `p[i] == c` via a pointer, `s->field == c`, …). No regression anywhere else.
- **v2 (follow-up):** computed/`Imag16`-resident LHS (`(a+b) == c`) — needs care that the *other* operand
  isn't a real-register value (which would force a spill); verify no-regression first.
- **v3 (follow-up):** abs-operand fold for globals (`g1 == g2`) — mirror `a16abscmp`/`CMPAbs16` so the
  global is read in place instead of materialized into `Imag16`.

Why v1 is the right core: it is the case that motivated all this (it **subsumes** the closed
indirect-s16-load follow-up), it is the **largest** per-site win (−4 B), and — crucially — it is
**immune to the interleaving regression** that killed the byte-wise-load approach, because a native 16-bit
EQ keeps the loaded value as **one 16-bit `Imag16` value** (no `G_UNMERGE` into two bytes, so no
two-byte-spill across interleaved 16-bit work).

## The gate signal (grounded in pre-legalizer GMIR)

What defines the EQ's operand vreg at `legalizeICmp` time (`-print-before=legalizer`):

| case | LHS def | verdict |
|---|---|---|
| `*p == c` (`eq_deref`) | `G_LOAD %p:(p0)` — **runtime pointer** | **native (−4)** ✓ |
| `g1 == g2` (`eq_glob`) | `G_LOAD` via `G_GLOBAL_VALUE` — **absolute** | 8-bit (v3) |
| `a == c` (`eq_ret`) | `G_MERGE_VALUES(COPY $a, COPY $x)` — **register arg** | 8-bit |
| `(a+b) == c` (`eq_local`) | `G_ADD` — computed/`Imag16` | 8-bit (v2) |

So the v1 predicate is exactly **"the operand's def is an s16 `G_LOAD` (or `G_LOAD16_INDIR`) whose pointer
is *not* an absolute address"** — i.e. `matchAbsoluteAddressing` fails on the load's pointer (the same
test `legalizeLoadStore16` uses to pick indirect vs absolute, `MOSLegalizerInfo.cpp:1748`).

## Design

Reuse the spike's two changes, but **gate** the relaxation on the indirect-load predicate (no new pseudo
— it rides the existing `buildNZSelect → MOSLowerSelect → G_BRCOND_IMM → selectBrCondImm → CmpBrImag16`
path proven by the spike).

1. **Helper** (`MOSLegalizerInfo.cpp`, near `legalizeICmp`):
   ```cpp
   // True if Reg is defined by an s16 load through a non-absolute (runtime) pointer —
   // i.e. the value already lands in Imag16, so a native 16-bit compare reads it directly
   // instead of unmerging it back into bytes. (Absolute/global loads stay 8-bit: v3.)
   static bool isIndirectS16Load(Register Reg, const MachineRegisterInfo &MRI) {
     MachineInstr *Def = getDefIgnoringCopies(Reg, MRI);   // look through COPY
     if (!Def || (Def->getOpcode() != TargetOpcode::G_LOAD &&
                  Def->getOpcode() != MOS::G_LOAD16_INDIR))
       return false;
     if (MRI.getType(Def->getOperand(0).getReg()) != LLT::scalar(16))
       return false;
     return !matchAbsoluteAddressing(MRI, Def->getOperand(1).getReg()).has_value();
   }
   ```
   (Check both `G_LOAD` and `G_LOAD16_INDIR` — legalization order may have already lowered it.)

2. **Relax the gate** (`MOSLegalizerInfo.cpp:1361`), rename `NativeS16EqBranch` → `NativeS16Eq`:
   ```cpp
   const bool anOperandIsIndirectLoad =
       isIndirectS16Load(LHS, MRI) || isIndirectS16Load(RHS, MRI);
   const bool NativeS16Eq =
       STI.hasAccum16() && Type == LLT::scalar(16) && Pred == CmpInst::ICMP_EQ &&
       !RHSIsZero &&
       (anOperandIsIndirectLoad ||                       // v1: indirect-load operand -> value or branch
        all_of(MRI.use_instructions(Dst), [](const MachineInstr &U) {
          return U.getOpcode() == MOS::G_BRCOND_IMM;      // existing: branch use
        }));
   ```

3. **Let `buildNZSelect` run for value uses** (`MOSLegalizerInfo.cpp:1454`) — drop the `!NativeS16 &&`
   guard (safe: when `!NativeS16` the guard was already a no-op):
   ```cpp
   if (!isNZUseLegal(Dst, MRI))
     Z = buildNZSelect(Z, Builder);
   ```

4. **Commutativity:** `selectBrCondImm`'s `m_CmpNZImag16` takes the `G_SBC` LHS into `A16`. EQ is
   commutative, so for `c == *p` (load on the RHS) the result is still correct (the load is the `cmp`
   operand, also in `Imag16`). Confirm in the disasm that both operand orders produce the native compare;
   if one order is worse, canonicalize the indirect-load operand to the LHS in the legalizer.

That's the whole v1: one helper + a gate disjunct + dropping one `&&`.

## Verification

1. **Win, disasm.** `*p == c` as a value under `+mos-a16`: one native 16-bit `rep; lda (zp)…; cmp; sep;
   beq/bne` + `ldx#1/stz`, **no** 8-bit `cpx/cmp` two-byte unmerge; `-verify-machineinstrs` clean; **byte
   count < the 8-bit baseline** (expect the spike's −4 B on `eq_deref`).
2. **No regression (the bar).** `a == c` (register), `g1 == g2` / `g1 == 0x1234` (global), `(a+b) == c`
   (computed) all stay **byte-identical to the pre-change baseline** (gate must not fire). Diff the disasm
   of `eqval.c`/`eqval2.c` native-vs-gated for these.
3. **16-bit-ambient re-measure (the lesson).** Put `*p == c` inside sustained 16-bit work (à la
   `ambient.c`) and confirm the −4 B holds (or at least never regresses) there too — native EQ should be
   immune to the interleaving problem (no byte unmerge), but **measure, don't assume**.
4. **Value correctness.** New `examples/65816/a16eqvalp.c` + `dev/a16eqvalp.sh`: `*p == c` / `*p != c` as
   stored values, `host == default == +mos-a16` on MAME + bsnes-jg.
5. **Non-breaking.** Full a16 suite + corpus 7/7 + `fuzz 50 1` 50/50 (touches indirect-s16-EQ-as-value
   sites). `dev/regen-patch.sh` round-trips (`0002`).

## Verification results (2026-06-16)

Implemented as designed: a lambda `isIndirectS16Load` + the gate disjunct (`NativeS16EqBranch` →
`NativeS16Eq`) + dropping `!NativeS16 &&` on the EQ `buildNZSelect`. Rebuilt the toolchain.

1. **Win, disasm — PASS.** `eq_deref` (`*p == c`): 38 → **34 B (−4)**, native `rep; lda (zp); cmp; sep`
   + 0/1 materialize; `-verify-machineinstrs` clean.
2. **No regression — PASS.** `eq_ret`/`ne_ret`/`eq_store`/`eq_arith` (register), `eq_glob`/`eq_globimm`
   (global), `eq_local`/`eq_local2` (computed), `eq_branch` (control): **all byte-identical** to the
   pre-change baseline (gate correctly does not fire).
3. **16-bit-ambient — PASS.** `*p == c` embedded in sustained 16-bit arithmetic: 1 native `cmp`, **0**
   `cpx/cpy`, verify-clean; the compare merges into the surrounding `rep`/`sep` region (no separate
   island). The byte-wise-style interleaving regression is structurally absent (the value stays one
   `Imag16` word — no byte split to carry).
4. **Value correctness — PASS.** `examples/65816/a16eqvalp.c` + `dev/a16eqvalp.sh`: native gate PASS,
   `corpus_result == 0x0101` host == default(MAME) == +mos-a16(MAME) == bsnes-jg.
5. **Non-breaking — PARTIAL (clean re: this change).** a16 **suite 44/44**, **corpus 7/7**. **Fuzz
   48/50, 0 mismatch / 0 error / 2 new-crash.** The 2 crashes are seeds 10 & 16 = the **F4** upstream
   late-opt `$y = TX $x` bug (`MOSLateOptimization::combineLdImm`, fixed in committed
   `patches/llvm-mos/0003-late-opt-txy-dead-flag.patch`), surfaced by the concurrent recursion-fuzzer
   work — **not** this change: seed 10's crashing `f1` has **zero** native-EQ artifacts, and seed 16's
   only native-16-bit artifact is the pre-existing *ordering* `CMPImm16`→carry→`BR` (not a Z-based
   EQ-value `CmpBrImag16`). My gate also excludes `RHSIsZero`, and both recursive functions' EQ is
   `p0 == 0`. `dev/regen-patch.sh` (`0002`) **not yet run** — deferred until vendor is synced to `0003`
   (see below), to avoid capturing the concurrent worker's in-flight late-opt edits.

**Resolution (2026-06-17):** the "blocker" was a misread — (1) the crashes were a **stale build** (my
toolchain was compiled ~39 min before F4's source landed); (2) `0003` "not applying" just meant it is
already in the live tree; (3) the one real gap — a `0002` regen absorbing F4 — was fixed by the F4 agent
in `dev/regen-patch.sh` (`a30f309`, which bakes `0003` into the regen baseline). After their rebuild
(= F4 + this EQ change), `fuzz 50 1` → **50/50, 0 mismatch / 0 crash**, and `regen-patch` produced a clean
`0002` (no F4 hunk; MOSLateOptimization refs unchanged). Committed `0002` + `a16eqvalp.c`/`.sh` + docs;
`0003` / `vendor/` untouched.

## Risks

- **Gate too broad / a residency I didn't foresee** → a regression. Mitigation: v1 fires only on a
  non-absolute s16 load (the one case the spike measured as a clean win); step-2 diff is the guard.
- **Commutativity** (load on RHS) → covered by step 4 + the differential fuzzer.
- **Legalization order** (load not yet `G_LOAD16_INDIR` when ICMP is processed) → the helper checks both
  `G_LOAD` and `G_LOAD16_INDIR`.
- **Blast radius:** every indirect-s16-`==`-as-value site. The Tier-1 differential fuzzer + a quiet box
  are the safety net.

## Follow-ups — ALL LANDED 2026-06-17

- ~~**v2 — computed/`Imag16` LHS** (`(a+b) == c`, −3 B)~~ **DONE** — gate-only `ComputedEq`
  ([v2 plan](2026-06-17-321-native-s16-eq-v2-computed-imag16-lhs.md)).
- ~~**v3 — abs-operand fold for globals** (`g1 == g2`)~~ **DONE** — `CmpBrAbsAbs16` (−48 B chained)
  ([v3 plan](2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md)); the `g1 == 0x1234` immediate
  sub-case followed via `getI16Const` + `CmpBrAbsImm16`
  ([const-merge plan](2026-06-17-321-native-s16-eq-imm-constant-through-merge.md)).
- Re-measure after **A16-threading** (ROADMAP step 5), which keeps s16 values in the accumulator and so
  shifts operand residency — likely widening where native EQ wins. (Still open.)
