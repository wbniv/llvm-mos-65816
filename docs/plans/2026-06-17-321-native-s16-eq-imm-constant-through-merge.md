# #321 — native s16 equality-vs-immediate: recover the byte-split constant (`g == 0x1234`)

**Date:** 2026-06-17
**Status:** **DONE — landed 2026-06-17.** The EQ matcher now recovers a 16-bit constant byte-split into
`G_MERGE_VALUES(i8,i8)` (shared `getI16Const`, also DRYs `getImm16Operand`); `g == 0x1234` value-EQ
folds to `rep; lda abs g; cmp #$1234; sep; beq/bne` (`CmpBrAbsImm16`), and the dormant `CmpBrImm16` is
lit up so v1's `*p == 0x1234` and the branch `if (g == 0x1234)` use `cmp #imm` instead of materializing
the constant. Verified: `a16eqvalg` (now incl. `g==0x1234`) native + `0x1101` on MAME+bsnes-jg, a16
suite + corpus + **fuzz 50/50** green, `-verify-machineinstrs` clean, `0002` round-trips.
The v3 follow-up deferred from
[v3 abs-fold](2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md).
**ROADMAP:** step 5 (M2) · **TODO:** M2 "native s16 equality-as-value — v2 + the `g1 == 0x1234` follow-up"
**Predecessor:** [v3 abs-fold (done)](2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md) —
landed `g1 == g2` (`CmpBrAbsAbs16`) and dropped the `g1 == 0x1234` pieces as dead code; this plan revives
them by removing the blocker.

## The blocker (root-caused during v3)

A 16-bit constant operand of the native 16-bit EQ `G_SBC` is **byte-split into
`G_MERGE_VALUES(G_CONSTANT i8 lo, G_CONSTANT i8 hi)`** during legalization (a `G_CONSTANT i16` is
illegal and narrowed) and never recombined before selection. The EQ constant matcher
`CmpNZImm16_match::match` (`MOSInstructionSelector.cpp:931`) recovers the RHS only via
`getIConstantVRegValWithLookThrough`, which does **not** see through `G_MERGE_VALUES` → it returns
`nullopt` → `m_CmpNZImm16` fails → selection falls to `m_CmpNZImag16` → `CmpBrImag16` with the constant
materialized (`LDImm16` → `cmp zp`). Verified during v3: `*p == const`, `if (g == const)`, and
`g == const` (value) **all** emit `CmpBrImag16`, never the existing `CmpBrImm16`.

**The ordering path already solved this.** `getImm16Operand` (`:2652`, used by `selectSbc16` /
`selectAlu16Native`) tries `getIConstantVRegValWithLookThrough` and, failing that, recognizes a
`G_MERGE_VALUES` of two byte constants and reconstructs `(hi<<8)|lo`. So `a < 0x1234` already folds to
`cmp #imm`; only the EQ matcher lacks the same recovery.

## Design

### 1. Shared merge-aware constant recovery (the core fix)

Add one static helper near the top of `MOSInstructionSelector.cpp` (before the `CmpNZ16` matchers,
~`:850`), factoring out the exact logic `getImm16Operand` already uses but on a `const MRI` so the
matchers can call it:

```cpp
// Recover a 16-bit constant whether it survived as a G_CONSTANT or was byte-split into
// G_MERGE_VALUES(i8 lo, i8 hi) during legalization (how a 16-bit constant operand of a
// native EQ/ALU op reaches selection under +mos-a16 — a G_CONSTANT i16 is illegal).
static std::optional<int64_t> getI16Const(Register R, const MachineRegisterInfo &MRI) {
  if (auto C = getIConstantVRegValWithLookThrough(R, MRI))
    return C->Value.getZExtValue() & 0xFFFF;
  MachineInstr *Def = getDefIgnoringCopies(R, MRI);
  if (Def && Def->getOpcode() == TargetOpcode::G_MERGE_VALUES &&
      Def->getNumOperands() == 3) {
    auto Lo = getIConstantVRegValWithLookThrough(Def->getOperand(1).getReg(), MRI);
    auto Hi = getIConstantVRegValWithLookThrough(Def->getOperand(2).getReg(), MRI);
    if (Lo && Hi)
      return ((Hi->Value.getZExtValue() & 0xFF) << 8) | (Lo->Value.getZExtValue() & 0xFF);
  }
  return std::nullopt;
}
```

- **Use it in `CmpNZImm16_match::match`** (`:931`): replace the bare
  `getIConstantVRegValWithLookThrough(operand 6)` with `getI16Const(operand 6, MRI)`.
- **DRY `getImm16Operand`** (`:2652`): reduce its body to `return getI16Const(R, MRI);` (same behaviour,
  one source of truth). `getI16Const` takes `const MRI`; `getImm16Operand`'s non-const `MRI&` binds fine.

A non-constant `G_MERGE_VALUES` (two byte *loads*, not constants) yields `nullopt`, so `m_CmpNZImm16`
still correctly declines `g == h` (both variables) — it falls to the `m_CmpNZImag16`/`CmpBrAbsAbs16` path.

### 2. Re-add the `CmpBrAbsImm16` fold (`g == 0x1234` → `lda abs; cmp #imm`)

These were written then removed in v3 (dead while the constant was unrecoverable). Re-instate:

- **Pseudo** `MOSInstrPseudos.td` (beside `CmpBrAbsAbs16`):
  `(ins label:$tgt, Flag:$flag, i1imm:$flag_val, addr16:$l, i16imm:$r)`, `Defs = [C, A16, NZ]`,
  `Predicates = [HasAccum16]`, in the `mayLoad` block.
- **Fold** in `selectBrCondImm`'s `m_CmpNZImm16` block: if `foldableAbsLoad16(LHS)` → emit
  `CmpBrAbsImm16` (lda abs g; cmp #imm) + the load's memref; erase the folded load. Else → existing
  `CmpBrImm16` (now reachable for `*p == imm` / materialized-LHS `g == imm`).
- **`expandCmpBr16`**: `CmpBrAbsImm16` → `LhsAbs = true`, `CmpOpc = CMPImm16` (LHS `lda abs`, RHS
  `cmp #imm`). Add to the dispatch (`:1057`) + `getBranchDestBlock` (`:355`).

### 3. Re-add the `GlobalVsImm` gate + canonicalization (value-use `g == 0x1234`)

`MOSLegalizerInfo.cpp` — so a **value** use of `g == imm` is kept native (a branch use already is, via the
all-`G_BRCOND_IMM` disjunct; the constant is still a plain `G_CONSTANT i16` at `legalizeICmp` time, before
it is byte-split, so `m_ICst` sees it):

```cpp
int64_t CstTmp;
const bool RHSIsCst = mi_match(RHS, MRI, m_ICst(CstTmp));
const bool LHSIsCst = mi_match(LHS, MRI, m_ICst(CstTmp));
const bool LHSIsZero = mi_match(LHS, MRI, m_SpecificICst(0));
const bool GlobalVsImm =
    (isFoldableAbsS16Load(LHS) && RHSIsCst && !RHSIsZero) ||
    (isFoldableAbsS16Load(RHS) && LHSIsCst && !LHSIsZero);   // g == K  /  K == g (nonzero K)
// ... add `|| GlobalVsImm` to NativeS16Eq, beside BothGlobal.
// Canonicalize a lone foldable global to the LHS so selectBrCondImm's CmpBrAbsImm16
// (which reads the const from RHS) fires for `K == g` too. EQ's Z is swap-symmetric.
if (NativeS16Eq && isFoldableAbsS16Load(RHS) && !isFoldableAbsS16Load(LHS))
  std::swap(LHS, RHS);
```

(`g == 0` stays on the `G_CMPZ` path — `!RHSIsZero` / `!LHSIsZero`.)

## Volatile / correctness

Same 1-to-1 single-use fold as v3 (`foldableAbsLoad16` → `lda abs`). `CmpBrAbsImm16` carries **one**
memref (the LHS global); `analyzeBranch`'s all-memref volatile scan (added in v3) already covers it. The
constant recovery is read-only and value-preserving (it reconstructs the same i16 the materialized form
computed).

## Verification steps

1. **`g == 0x1234` value folds — PASS.** `examples/65816/a16eqvalg.c` extended with `r3 = (g0 == 0x1234)`;
   post-isel MIR shows **3 `CmpBrAbsAbs16` + 1 `CmpBrAbsImm16`**, disasm `lda abs; cmp #$1234` (the
   constant compared directly, no `LDImm16`/`cmp zp` materialization):

   ```
   PASS: 3 cmp abs/long (g1==g2 globals read directly)
   PASS: 1 cmp #imm16 (g==0x1234 folds the global + cmp #imm, no const materialization)
   PASS: no cmp zp — no global/constant round-tripped through an Imag16 pair
   PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)
   SMOKE: PASS got=0x1101 (MAME default / MAME +mos-a16 / bsnes-jg)
   ```
   `-verify-machineinstrs` clean. **PASS.**

2. **`CmpBrImm16` lights up — PASS.** `if (g0 == 0x1234)` (branch) and `*pp == 0x1234` (v1 indirect)
   each now select **`CmpBrImm16`** → `cmp #$1234` with `cmpzp=0` (was `CmpBrImag16` + materialized
   `LDImm16`/`cmp zp`). Both smaller.

3. **No regression — PASS.** `dev/run.sh a16eqvalg a16eq a16eqval a16eqvalp a16cmp a16scmp a16abscmp
   a16loop a16localimm a16imm a16chainimm` all green — the immediate-fold tests (`a16imm`/`a16localimm`/
   `a16chainimm`, which drive `getImm16Operand`) confirm the shared-helper refactor is byte-identical.

4. **Non-breaking — PASS.** Full a16 suite + `dev/run.sh corpus` (7/7) green; `dev/run.sh fuzz 50 1` →
   **`50/50 PASS, 0 mismatch / 0 new-crash / 0 error`**.
5. `dev/regen-patch.sh` (host) → **`RESULT: PASS — 0002 round-trips`**. **PASS.**

## Risks

- **Matcher over-matches** → a non-constant `G_MERGE_VALUES` wrongly treated as imm. Mitigation:
  `getI16Const` requires both merge sources to be `G_CONSTANT` (via `getIConstantVRegValWithLookThrough`);
  byte loads return `nullopt`. The fuzzer is the net.
- **`getImm16Operand` refactor changes ordering codegen** → guard: it now *calls* the extracted helper
  with identical logic; step 3 (`a16cmp`/`a16scmp`/`a16loop`) confirms byte-identical.
- **Gate fires but fold misses** (cross-block / multi-use) → falls to `CmpBrImm16` (still drops the const
  materialization) → no regression. Same robustness as v3.
