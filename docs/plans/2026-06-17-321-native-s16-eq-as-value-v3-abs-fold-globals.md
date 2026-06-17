# #321 — native s16 equality-as-value v3: abs-operand fold for globals (`g1 == g2`)

**Date:** 2026-06-17
**Status:** **DONE (both-global fold) — landed 2026-06-17.** `g1 == g2` equality-as-value (and branch
`if (g1 == g2)`) now folds to native `rep; lda abs; cmp abs; sep; beq/bne` (`CmpBrAbsAbs16`).
Measured **−48 B (−24 %)** on a chained 3-compare test vs the pre-v3 8-bit baseline. Code:
`MOSInstrPseudos.td` (one pseudo `CmpBrAbsAbs16`), `MOSInstrInfo.cpp` (dispatch + `expandCmpBr16` +
`getBranchDestBlock` + `analyzeBranch` multi-memref volatile scan), `MOSInstructionSelector.cpp`
(`selectBrCondImm` both-global fold + `foldableAbsLoad16` forward-decl), `MOSLegalizerInfo.cpp`
(`isFoldableAbsS16Load` + `BothGlobal` gate disjunct). New test `examples/65816/a16eqvalg.c` +
`dev/a16eqvalg.sh`; stale gates in `a16eq`/`a16eqval` updated (v3 improved their global compares).
All gates green: a16eqvalg native + 0x0101 (MAME+bsnes-jg), a16 suite 36/36, corpus 7/7,
**fuzz 50/50**, `-verify-machineinstrs` clean, `0002` round-trips. **`g1 == 0x1234` deferred** (the
16-bit constant is byte-split before selection — blocks `CmpBrAbsImm16` and the dormant `CmpBrImm16`
alike; see Scope + Follow-ups). v1 (indirect `*p == c`, −4 B) landed 2026-06-17. v3 adds an
**abs-operand fold** to the native EQ-as-value path so a global operand is read in place
(`lda abs` / `cmp abs`) instead of being round-tripped through an `Imag16` pair — turning the
blanket-native **regressions** the spike measured for globals (`g1 == g2` **+4 B**, `g1 == 0x1234`
**+12 B**) into wins, while staying no-regression everywhere else (the gate fires only where the fold
applies). Mirrors `selectSbc16`'s `a16abscmp` fold (`CMPAbs16`/`LDAbs16`).
**ROADMAP:** step 5 (M2) · **TODO:** M2 "native s16 equality-as-value — v2/v3"
**Predecessors / evidence:**
[v1 gated impl](2026-06-16-321-native-s16-eq-gated-impl.md) — landed the gate + the
`buildNZSelect → MOSLowerSelect → G_BRCOND_IMM → CmpBrImag16` value path (no new pseudo for v1) ·
[design + spike](2026-06-16-321-native-s16-eq-as-value-cmpsel.md) — the spike measured the per-shape
bytes (the regression table below is from it) ·
[a16abscmp / compare-operand fold](2026-06-15-321-native-16bit-compare-abs-operand-fold.md) — the
**precedent v3 mirrors**: `selectSbc16` reads near-abs globals via `lda abs` (`LDAbs16`) / `cmp abs`
(`CMPAbs16`) on the *ordering* path; v3 brings the same fold to the *equality* path.
**Principle:** modest gains are worth doing on a compiler — amplified across every program built with
the toolchain ([[modest-gains-worth-doing]]); the fold is what makes the global EQ-as-value
**regression-free**, which is the bar.

## The regression v3 turns into a win (from the spike)

The v1 spike (`2026-06-16-321-native-s16-eq-as-value-cmpsel.md`) measured *blanket* native EQ-as-value
vs today's 8-bit two-byte chain. Globals **regress** because the native EQ path has **no abs-operand
fold** — it materializes each global into an `Imag16` pair (`lda abs; sta tmp` ×2) before the compare,
where the 8-bit chain reads them tightly (`lda g; cmp #imm` / `cmp g`):

| operand residency | shape | 8-bit B | blanket-native B | Δ | v3 |
|---|---|--:|--:|--:|---|
| global vs immediate | `eq_globimm` (`g1 == 0x1234`) | 28 | 40 | **+12** | **fold → win** |
| global vs global | `eq_glob` (`g1 == g2`) | 34 | 38 | **+4** | **fold → win** |
| indirect deref | `eq_deref` (`*p == c`) | 38 | 34 | −4 | **v1 (landed)** |
| `Imag16` (computed) | `eq_local` (`(a+b) == c`) | 46 | 43 | −3 | v2 (separate) |
| register / param | `eq_ret` / `eq_store` | 22 / 17 | 30 / 25 | +8 | stays 8-bit (no fold possible) |

The mechanism is exactly the one `a16abscmp` already fixed for ordering compares: a single-use near-abs
`G_LOAD16_ABS` selected on its own becomes `lda abs; sta tmp(Imag16)` — a wasteful round-trip when the
next op only needs it in `A16` / as a compare operand. Fold it into `lda abs` (LHS) / `cmp abs` (RHS)
and the round-trip disappears.

## Scope — `g1 == g2` (both-global), shipped; `g1 == 0x1234` deferred

**Shipped:** v3 fires the native EQ path and folds when **both** operands are single-use near-abs
16-bit global loads — `g1 == g2` → `rep; lda abs g1; cmp abs g2; sep; beq/bne` + 0/1 diamond
(`CmpBrAbsAbs16`). This is the headline `g1 == g2` case and is verified (single & independent
compares fold cleanly; net **−48 B** on a chained 3-compare test vs the pre-v3 8-bit baseline). The
fold also fires for **branch** uses of `g1 == g2` (`if (a == b)`) — a free improvement over the prior
`CmpBrImag16` round-trip; it lit up `a16eq`/`a16eqval` (their stale gates were updated).

**Deferred — `g1 == 0x1234` (global vs immediate):** during implementation the 16-bit constant proved
to be **byte-split into `G_MERGE_VALUES(i8,i8)` before selection** (it never survives as a `G_CONSTANT
i16`), so the constant-matcher `m_CmpNZImm16` cannot recover it — the same reason the **existing**
`CmpBrImm16` never fires (verified: `*p == const` and `if (g == const)` both emit `CmpBrImag16` with the
constant materialized). So a `CmpBrAbsImm16` would be dead code. The fix is to teach the `CmpNZ16`
matcher to recover the i16 constant through `G_MERGE_VALUES` of two byte constants (which would also
light up the dormant `CmpBrImm16`, helping v1's `*p == c`) — a separate follow-up. Until then `g == imm`
stays on its pre-v3 path (8-bit), i.e. **no regression**, just not yet optimized.

**Out of scope (deliberately, to stay no-regression):**

- **Mixed global-vs-register / global-vs-computed-local** (`g1 == a`, `g1 == (b+c)`): only one operand
  folds; the other forces an `Imag16` spill or stays a register the 8-bit `cpx;cmp` reads directly. The
  gate requires **both** operands foldable (`BothGlobal`), so v3 does **not** fire for it (the
  global-vs-`Imag16`-local shape can be revisited with **v2**, which owns the computed/`Imag16`-LHS
  residency question).
- **Register / param operands** (`eq_ret`, `eq_store`): no foldable load → stays 8-bit. Unchanged.
- **`g1 == 0`** (`RHSIsZero`): stays on the existing `G_CMPZ` zero-compare path (`!RHSIsZero` guard).
- **Chained value-EQ where loads are hoisted cross-block** (`r = (g1==g2) | ((g3==g4)<<4) | …` deep in
  one expression): `MOSLowerSelect` splits the select diamonds so a later compare's operand loads land
  in a *dominating* block, separate from the compare-branch. `foldableAbsLoad16` (correctly) refuses to
  fold across blocks (sinking a **volatile** load into a conditional successor would change when it
  executes), so those compares stay native-but-materialized (`CmpBrImag16`). **Not a regression** — even
  the materialized native form beats the 8-bit chain in 16-bit-ambient code (the −48 B measurement
  *includes* such partially-folded compares); just a missed sub-optimization. Independent statements
  (`r0 = (g1==g2); r1 = …`) fold fully.

## How it works today (grounded)

The v1 value path (`MOSLegalizerInfo.cpp` / `MOSInstructionSelector.cpp` / `MOSInstrInfo.cpp`):

1. **Legalizer gate** (`legalizeICmp`, `MOSLegalizerInfo.cpp:1364–1383`): `NativeS16Eq` keeps the s16
   `ICMP_EQ` un-narrowed when `isIndirectS16Load(LHS|RHS)` **or** every use is `G_BRCOND_IMM`. It then
   builds a **16-bit `G_SBC`** (`:1465–1474`); a **value** use of its `Z` is wrapped by `buildNZSelect`
   (`:1472`, the `!isNZUseLegal` branch).
2. **Select lowering** turns that `G_SELECT(Z16, -1, 0)` into a `G_BRCOND_IMM %Z16` diamond
   (`MOSLowerSelect`), with `ldx #1` / `stz` materializing 0/1.
3. **Selection** (`selectBrCondImm`, `MOSInstructionSelector.cpp:1170–1191`): `m_CmpNZImm16` /
   `m_CmpNZImag16` (`:927–960`) match the 16-bit `G_SBC` (operand 5 = LHS, operand 6 = RHS, live flag
   `Z`) and emit **`CmpBrImm16`** / **`CmpBrImag16`** (`MOSInstrPseudos.td:370–379`).
4. **Post-RA expand** (`expandCmpBr16`, `MOSInstrInfo.cpp:1387–1411`): `LDAImag16 A16,$l;
   CMP{Imag16,Imm16} A16,$r (defs Z); BR(Z)` — the lda/cmp are `MLow=1` so `MOSInsertREPSEP` brackets
   them with `rep`/`sep`; the inserted `sep` doesn't touch `Z`, so `BR` reads it.

**Why globals regress here:** when `$l` / `$r` are globals, the matcher sees the s16 `G_SBC`'s operands
as `G_LOAD16_ABS` vregs that select **independently** to `lda abs; sta tmp(Imag16)`, and the pseudo then
reads them back with `LDAImag16` / `CMPImag16`. Two `sta`/`lda` round-trips that the fold removes.

The ordering path already solved this: `selectSbc16` (`:1320–1370`) calls `foldableAbsLoad16`
(`:1303–1310`) on each operand and emits `LDAbs16` (LHS) / `CMPAbs16` (RHS) directly, erasing the
single-use folded loads. v3 brings that fold to the EQ branch-pseudo path.

## Design

Three changes — a gate disjunct, one new fused pseudo, and the fold in `selectBrCondImm` (+ its
expansion). No new inserter; the value path still rides the v1 `buildNZSelect → … → CmpBr*` chain.
**As shipped, the gate disjunct and the fold are both-global-only** (`g1 == g2`); the `g1 == 0x1234`
pieces were planned but dropped during implementation (see Scope — the 16-bit constant is byte-split
before selection, so the matcher can't recover it; `CmpBrAbsImm16` would be dead code).

### 1. Gate: fire native EQ when both operands are foldable near-abs global loads

`MOSLegalizerInfo.cpp`, beside the existing `isIndirectS16Load` lambda (`:1364`):

```cpp
// True if Reg is defined by a SINGLE-USE s16 load of an ABSOLUTE (global) address —
// the operand selectBrCondImm's abs-fold reads in place via `lda abs` / `cmp abs`
// (foldableAbsLoad16), instead of the wasteful `lda abs; sta tmp(Imag16)` round-trip.
// Mirror of isIndirectS16Load with the abs test inverted + a single-use requirement
// (the fold is 1-to-1 / volatile-safe only for a single consumer).
auto isFoldableAbsS16Load = [&](Register Reg) -> bool {
  MachineInstr *Def = getDefIgnoringCopies(Reg, MRI);
  if (!Def || (Def->getOpcode() != TargetOpcode::G_LOAD &&
               Def->getOpcode() != MOS::G_LOAD16_ABS))
    return false;
  if (MRI.getType(Def->getOperand(0).getReg()) != LLT::scalar(16))
    return false;
  if (!MRI.hasOneNonDBGUse(Def->getOperand(0).getReg()))
    return false;
  return matchAbsoluteAddressing(MRI, Def->getOperand(1).getReg()).has_value();
};
```

Add a v3 disjunct to `NativeS16Eq` — **`BothGlobal` only** (the `globalVsImm` disjunct was planned but
dropped, see Scope), so only `g1 == g2` (and `if (g1 == g2)`) newly goes native:

```cpp
const bool BothGlobal = isFoldableAbsS16Load(LHS) && isFoldableAbsS16Load(RHS);   // g1 == g2
const bool NativeS16Eq =
    STI.hasAccum16() && Type == LLT::scalar(16) && Pred == CmpInst::ICMP_EQ &&
    !RHSIsZero &&
    (isIndirectS16Load(LHS) || isIndirectS16Load(RHS) ||   // v1
     BothGlobal ||                                         // v3 (this plan)
     all_of(MRI.use_instructions(Dst), [](const MachineInstr &U) {
       return U.getOpcode() == MOS::G_BRCOND_IMM;
     }));
```

(No canonicalization swap is needed: `BothGlobal` means both operands fold either way, and EQ's `Z` is
order-symmetric. The swap + the `m_ICst` const-flags from the original sketch were removed with
`globalVsImm`.)

Note: the gate checks the load in its **pre-`legalizeLoadStore16`** form (`G_LOAD` of a `G_GLOBAL_VALUE`
that `matchAbsoluteAddressing` accepts, exactly as `isIndirectS16Load` checks both `G_LOAD` and
`G_LOAD16_INDIR`); by selection time it is `G_LOAD16_ABS`, which `foldableAbsLoad16` matches. The
`hasOneNonDBGUse` check keeps the gate and the selector's fold in agreement (single-use is also
`foldableAbsLoad16`'s requirement) — so if a foldable abs load is the operand, the fold *will* fire and
we never emit the `Imag16` round-trip the spike measured as a regression.

### 2. One new fused pseudo `CmpBrAbsAbs16` (both operands read via `lda abs` / `cmp abs`)

`MOSInstrPseudos.td`, beside `CmpBrImag16` / `CmpBrImm16` (`:370`), inside the existing
`let mayLoad = true in { … }` block:

```tablegen
// #321 v3: native s16 EQ folding BOTH near-abs GLOBAL operands (g1 == g2). LHS read by
// `lda abs` (LDAbs16), RHS by `cmp abs` (CMPAbs16) — no Imag16 round-trip. expandCmpBr16
// lowers to `LDAbs16 $l; CMPAbs16 $r; BR`. Carries the two folded loads' memrefs.
def CmpBrAbsAbs16 : MOSCmpBr {        // g1 == g2
  let Predicates = [HasAccum16];
  let Defs = [C, A16, NZ];
  dag InOperandList = (ins label:$tgt, Flag:$flag, i1imm:$flag_val, addr16:$l, addr16:$r);
}
```

(`addr16` is the exact operand class `LDAbs16` / `CMPAbs16` already use — `MOSInstrLogical.td:601, 775`.)
**Why a fused pseudo** and not separate `LDAbs16; CMPAbs16; BR` in the selector: `Z` must stay live with
nothing scheduled between the `cmp` and the `BR` — the very reason `CmpBr*` bundles compare+branch and
declares `Defs = [C, A16, NZ]`. (The *ordering* path can use separate instrs because it tests `C`, which
survives the `sep`; equality tests `Z` and cannot.) The planned `CmpBrAbsImm16` was **not** added — the
constant never reaches selection as a matchable immediate (Scope).

### 3. `expandCmpBr16`: handle the abs-folded form

`MOSInstrInfo.cpp` — add `MOS::CmpBrAbsAbs16` to the dispatch (`:1057`) and `getBranchDestBlock`
(`:355`), and generalize `expandCmpBr16` (`:1387`) to pick the LHS/RHS opcodes from the pseudo:

```cpp
// LHS: CmpBrAbsAbs16 -> LDAbs16 (reads the global into A16); else LDAImag16.
const bool LhsAbs = Op == MOS::CmpBrAbsAbs16;
auto LDA = Builder.buildInstr(LhsAbs ? MOS::LDAbs16 : MOS::LDAImag16)
    .addDef(MOS::A16).add(MI.getOperand(3));            // op3 = $l (addr16 or Imag16)
if (LhsAbs) LDA.cloneMemRefs(MI);
// RHS: CMPAbs16 (abs) / CMPImm16 (imm, the existing CmpBrImm16) / CMPImag16 (zp).
unsigned CmpOp = (Op == MOS::CmpBrAbsAbs16) ? MOS::CMPAbs16
               : (Op == MOS::CmpBrImm16)    ? MOS::CMPImm16
               : MOS::CMPImag16;
auto CMP = Builder.buildInstr(CmpOp).addDef(MOS::C, RegState::Dead)
              .addUse(MOS::A16).add(MI.getOperand(4));   // op4 = $r
if (CmpOp == MOS::CMPAbs16) CMP.cloneMemRefs(MI);        // carry the folded loads' memrefs
CMP.addDef(Flag, RegState::Implicit);
Builder.buildInstr(MOS::BR).add(MI.getOperand(0)).addUse(Flag, RegState::Kill).add(MI.getOperand(2));
```

(`LDAbs16` also needs the LHS load's memref — attach via `cloneMemRefs` on the lda, sourced from the
pseudo. Confirm both abs accesses carry their memrefs so alias analysis / `-verify-machineinstrs` stay
clean; the 8-bit `CmpBrAbs` is the reference for memref plumbing.)

### 4. The fold in `selectBrCondImm` (mirror `selectSbc16`)

`MOSInstructionSelector.cpp`, in the `m_CmpNZImag16(LHS, RHS16)` block (both operands registers), before
falling to the plain `CmpBrImag16` emission. Call `foldableAbsLoad16` on the matched `LHS` / `RHS`
(passing the branch `MI` as the `User` — same block as the loads):

- If `foldableAbsLoad16(LHS)` **and** `foldableAbsLoad16(RHS)` → emit **`CmpBrAbsAbs16`** with each
  load's `getOperand(1)` (the abs operand) + `cloneMergedMemRefs({LdL, LdR})`; erase both loads.
- Otherwise (a lone foldable global = the out-of-scope mixed case, which the `BothGlobal` gate never
  admits for a value use but *can* reach via a branch use) → fall through to the existing `CmpBrImag16`.
  No partial fold.

The `m_CmpNZImm16` block is **unchanged** (the `CmpBrAbsImm16` fold was dropped — Scope).

Erase the folded `G_LOAD16_ABS` loads after constraining the new pseudo, **mirroring `selectSbc16`'s
erase order**: they are single-use and the 16-bit `G_SBC` was their only consumer. The now-dead `COPY`
(`Dst ← Z`) and the dead pure `G_SBC` are removed by `InstructionSelect::selectInstr`'s `isTriviallyDead`
pre-check (`InstructionSelect.cpp:361`) before either could re-select — so the erased loads are never
left dangling at a verifier point. `-verify-machineinstrs` confirms (clean).

### 5. Terminator bookkeeping (extra sites the new pseudo must appear in)

`CmpBrAbsAbs16` derives from `MOSCmpBr` (`isBranch`/`isTerminator`), so generic
`analyzeBranch`/`insertBranch` reconstruct it by opcode + operands. Two MOS-specific switches needed it:
`getBranchDestBlock` (return `operand(0)` as the target — added) and `analyzeBranch`'s volatile guard.
The latter previously `assert`ed a CmpBr has **at most one** mem operand and tested only that one for
volatility; `CmpBrAbsAbs16` carries **two** (the folded `lda abs` + `cmp abs` globals), so the check now
scans **all** mem operands for `isVolatile()` (`llvm::any_of`). This keeps the "don't reorder/reverse a
volatile compare-branch" protection intact — and is why folding even a *volatile* global is safe: a
volatile compare-branch is left unanalyzed, and the cloned volatile MMOs ride through `expandCmpBr16`
onto the final `lda abs`/`cmp abs`.

## Volatile safety

Identical to `a16abscmp`: folding a **single-use** `G_LOAD16_ABS` into `lda abs` / `cmp abs` is a 1-to-1
rewrite — exactly one read of the global still happens, in the same program order — so it is safe even
for volatile globals (`foldableAbsLoad16` gates on `hasOneNonDBGUse` + same-BB, *not* on
`shouldFoldMemAccess`). The gate's `hasOneNonDBGUse` keeps the legalizer in step. The cross-block case
(loads hoisted away from the compare) is **not** folded — sinking a volatile load into a conditional
successor would change when it executes (see Scope); the same-BB requirement is exactly that guard.

## Measurement (the win is not assumed — the predecessor discipline)

Per the indirect-load / spike lesson, **measure bytes-first under `-Os`, in 16-bit-ambient code** (where
`+mos-a16` actually runs — M=0 sustained across compute), not isolated leaf functions:

1. Re-measure the spike's `eq_glob` (`g1 == g2`) and `eq_globimm` (`g1 == 0x1234`) **with the fold**.
   Bar: **≤ the current 8-bit baseline** (28 B / 34 B from the spike table) — the no-regression bar;
   expected **strictly below** it (the fold removes 2–4 round-trip bytes per global operand).
2. Confirm the **in-scope-only** restriction holds: `eq_ret` / `eq_store` (register), `eq_local`
   (computed) and any global-vs-register mixed shape stay **byte-identical** to the pre-v3 baseline (the
   gate must not fire for them).
3. If `g1 == g2` lands at mere parity rather than a strict win in some ambient/schedule, that still
   clears the bar (no regression) — but capture the number; do **not** ship a shape that regresses.

## Verification steps

1. `dev/run.sh a16eqvalg` — **new test** `examples/65816/a16eqvalg.c` + `dev/a16eqvalg.sh`: three
   independent both-global value compares (`g0==g1`, `g0==g2`, `g0!=g2`); disasm gate (native `cmp
   abs/long`, no `cmp zp` round-trip, no 8-bit `cpx/cpy`), `-verify-machineinstrs` clean, `host ==
   default == +mos-a16` on MAME + bsnes-jg.

   ```
   PASS: 5 rep #$20 bracket(s) — native 16-bit compares
   PASS: 3 cmp abs/long (g1==g2 globals read directly)
   PASS: no cmp zp — no global round-tripped through an Imag16 pair
   PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)
   SMOKE: PASS got=0x0101 (MAME default) / got=0x0101 (MAME +mos-a16) / got=0x0101 (bsnes-jg)
   ```
   **PASS.**

2. **No regression / it's a win (the bar).** Byte size of `a16eqvalg` `.text.main` under `+mos-a16`,
   v3 vs the same source with the v3 gate disabled (value-EQ globals on the 8-bit path), measured on the
   original chained 4-compare variant:

   ```
   pre-v3 baseline (8-bit chain):  0xca = 202 bytes
   v3 (native abs-fold):           0x9a = 154 bytes   ->  -48 B (-24%)
   ```
   Confirms the plan's thesis: in 16-bit-ambient code even the *non-folded* native compares beat the
   8-bit chain — the spike's +4/+12 "regressions" were isolated-leaf artifacts. **PASS (a net win).**

3. `dev/run.sh a16eqval a16eqvalp a16abscmp a16eq a16cmp a16scmp` — existing equality/compare suite.
   `a16eqvalp` (v1 indirect), `a16abscmp` (ordering fold), `a16cmp`, `a16scmp` unchanged → PASS.
   `a16eq` (branch `if(a==b)`, globals) and `a16eqval` (value, globals) **improved** by the v3 fold from
   `cmp zp` (CmpBrImag16 round-trip) to `cmp abs/long` (CmpBrAbsAbs16); their stale disasm gates were
   updated (count `cmp long`/`cf`; the cross-block REP/SEP merge reduces `sep` count) — both PASS, values
   `0x0011` / `0x0101` unchanged on both emulators. **PASS.**

4. **Non-breaking.** Full a16 suite (36 incl. `a16eqvalg`) + `dev/run.sh corpus` (7/7) all PASS; the
   `+mos-a16` gate leaves default codegen untouched (corpus). `dev/run.sh fuzz 50 1` →
   **`50/50 PASS, 0 known-issue, 0 mismatch, 0 new-crash, 0 error`** (touches every s16 `==`-as-value
   site). **PASS.**
5. `-mllvm -verify-machineinstrs` clean on `a16eqvalg` and `a16eq` (step 1 / step 3). **PASS.**
6. `dev/regen-patch.sh` (host) → **`RESULT: PASS — 0002 round-trips (reapplied MOS dir == live
   vendor)`** (21 files, 3646 lines; no `0003`/F4 leakage). **PASS.**

## Risks (how each resolved)

- **Gate / fold disagreement** → a missed fold ships the `Imag16` round-trip. **Resolved by measurement:**
  even the materialized native form beats 8-bit in ambient (step 2, −48 B *with* partial folds), so a
  missed fold is a missed-optimization, not a regression. The gate (`BothGlobal`) + `foldableAbsLoad16`
  share the single-use + abs conditions; a cross-block hoist (the one place the fold misses) falls back
  to `CmpBrImag16`, still a win.
- **Dead `G_SBC` / dangling folded-load operands** → `-verify-machineinstrs` failure. **Resolved:**
  `InstructionSelect::selectInstr`'s `isTriviallyDead` pre-check removes the dead `COPY` + pure `G_SBC`
  before re-selection; verifier clean (step 5).
- **Memref plumbing** (two abs accesses) → alias/verifier issues. **Resolved:** `cloneMergedMemRefs` on
  the pseudo + per-form clone in `expandCmpBr16`; `analyzeBranch` scans all memrefs for volatility
  (its old single-memref assert would have fired). Verifier + volatile a16eqvalg clean.
- **Blast radius:** every s16 global-`==`-as-value site. **Net:** fuzz 50/50, a16 suite 36/36, corpus
  7/7 on a quiet box.

## Follow-ups (deferred, documented)

- **`g1 == 0x1234` (global vs immediate)** — ~~deferred (the 16-bit constant is byte-split before
  selection)~~ **DONE 2026-06-17** in
  [eq-imm constant-through-merge](2026-06-17-321-native-s16-eq-imm-constant-through-merge.md): the EQ
  matcher now recovers the byte-split constant (`getI16Const`), `g == 0x1234` folds via `CmpBrAbsImm16`
  (`lda abs; cmp #imm`), and the dormant `CmpBrImm16` is lit up for v1's `*p == c` + `if (g == c)`.
- **Mixed `g == local` / chained-cross-block** — only one operand folds (or the loads are hoisted into a
  dominating block); folding a volatile load cross-block is unsafe. These stay native-but-materialized
  (a win in ambient, not a regression). v2 (computed/`Imag16`-LHS) is the natural home for the mixed shape.

## Sequencing

Best done as part of / after **A16-threading** (ROADMAP step 5), which keeps s16 values in the
accumulator and so **changes operand residency** — re-measure then, as it likely *widens* where the
gated native EQ wins (a global that is already live in `A16` may not even need the `lda abs`). v3 is
independent of **v2** (computed/`Imag16`-LHS); they touch the same gate but disjoint operand shapes
(v2 = computed/local, v3 = global) — land either order, re-run the no-regression diff after each.
