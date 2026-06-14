# #321 native s16 — 16-bit comparisons (`rep; lda; cmp; sep; b<cc>`)

**Status: SLICE 1 DONE (2026-06-14).** Unsigned-ordering compares (`< <= > >=`) are native: the
legalizer keeps s16 UGE un-narrowed under `hasAccum16` (emits a 16-bit `G_SBC`), `selectSbc16` lowers
it to `lda; cmp; ` (one rep/sep bracket) producing C, and the branch reads C (`bcc`/`bcs`). New
`CMPImag16`/`CMPAbs16`/`CMPImm16` (`MLow=1`); a constant RHS folds to `cmp #imm16` (CMP_Immediate16
exists via the `CC1_All` multiclass). `a16cmp.c` (four orderings + a high-byte-differs case) shows 5
16-bit `cmp`, zero 8-bit `cpx/cpy`, and `0x1103` on both MAME and bsnes-jg. Non-breaking: corpus 7/7,
all 13 a16* tests green; patch `0002` round-trips. **Deferred follow-ups:** equality (`== !=`, Z →
`CmpBr` fusion), signed (N^V), compare→select, RHS global load-fold into `CMPAbs16`.

## Context

A 16-bit comparison (`if (a16v < b16v)`) currently **narrows to an 8-bit compare chain** in
`legalizeICmp` (MOSLegalizerInfo.cpp:1297-1366): split into high/low bytes, `cpy high; bne; cpx low`
across several basic blocks (verbose, slow). Under `+mos-a16` the 65816 can compare 16 bits in one op:
`rep #$20; lda a16v; cmp b16v; sep #$20; bcc …`. This is step 2 of the agreed optimization order and
the keystone for real control flow / loops (everything `for (i<n)` depends on it).

## Key mechanism (from the code)

`legalizeICmp` canonicalizes every predicate to **EQ / UGE / SLT** (via `negateInverseComparison` /
`swapComparison`, :1259-1275), then lowers each through a **generic, width-flexible `G_SBC`**
(:1373-1425) and copies the right flag to the i1 result:
- **UGE → C flag** (`Sbc.getReg(1)`, :1387) — a plain i1 copy; the branch tests C (`bcc`/`bcs`).
- **EQ → Z flag** (:1377) — but `selectSbc` asserts N/Z must be consumed by a **terminator**
  (MOSInstructionSelector.cpp:1161), i.e. fused into the branch (`CmpBr`). Harder.
- **SLT → N (or N^V)** (:1391-1419) — the signed overflow dance. Hardest.

Since `G_SBC` is width-flexible, a native 16-bit compare = emit a **16-bit `G_SBC`** instead of
narrowing, and reuse the *identical* flag→branch logic. The 16-bit `G_SBC` selects to `lda lhs; cmp
rhs` (both `MLow=1`, auto-bracketed by `MOSInsertREPSEP`) producing C/N/V/Z 16 bits wide; `sep` does
not touch C/Z/N, so the following branch reads them correctly.

## Scope — slice 1: unsigned **ordering** compares (`< <= > >=`)

These all reduce to **UGE** (C flag), the path with no terminator-fusion complexity. Covers the bulk
of loop conditions. **Deferred to follow-ups:** equality (`== !=`, Z → needs 16-bit `CmpBr` fusion);
signed (`slt/sle/sgt/sge`, N^V); compares feeding a `select`/bool-materialization rather than a branch.

### Step 1 — legalizer keeps s16 UGE native (MOSLegalizerInfo.cpp `legalizeICmp`)

Gate: `bool NativeS16 = STI.hasAccum16() && Type == S16 && Pred == ICMP_UGE;`. When set, **skip** the
narrowing block (`if (Type != S8 && !NativeS16) { …narrow… } else { CIn = const(1); }`), relax
`assert(Type == S8)` to allow S16, and parameterize the UGE case's `G_SBC` result type:
`LLT CmpTy = NativeS16 ? S16 : S8; buildInstr(G_SBC, {CmpTy,S1,S1,S1,S1}, {LHS,RHS,CIn})` → copy C to
Dst. EQ/SLT keep narrowing (unchanged) so only UGE goes native this slice.

### Step 2 — new 16-bit CMP ops (MOSInstrLogical.td)

Beside `SBCAbs16` (which is the model): `CMPImag16` (cmp zp, `Ac16` vs `Imag16`), `CMPAbs16` (cmp
abs16), `CMPImm16` (cmp #imm16) — each `MOSCMP`-like, `isCompare`, `MLow=1`, `Predicates=[HasAccum16]`,
`PseudoInstExpansion` to the 8-bit `CMP_*` forms, `OutOperandList=(outs Cc:$carry)`,
`InOperandList=(ins Ac16:$l, …)`. The pre-existing `LDAbs16`/`LDAImag16` load the LHS into A16.

### Step 3 — select the 16-bit `G_SBC` (MOSInstructionSelector.cpp)

A 16-bit `G_SBC` (operand-0 type S16, result A & V unused, carry-in set) → emit `lda lhs; cmp rhs`
producing C, mirroring `selectAlu16Native`/`selectAlu16AbsLd`'s operand-mode dispatch: LHS loaded via
`LDAbs16`(folded near-abs global)/`LDAImag16`(Imag16); RHS via `CMPAbs16`(global)/`CMPImm16`(const)/
`CMPImag16`(Imag16). The result is discarded; C is the def. **No `Ac16`↔8-bit COPY** (the invariant).
Detect this case before the 8-bit `selectSbc` body (which hardcodes 8-bit CMP opcodes + `assert(BitWidth
== 8)`); route s16 `G_SBC` to a new `selectSbc16` helper.

### Step 4 — tests

`examples/65816/a16cmp.c`: the four orderings, e.g. `corpus_result = (a16v < b16v) ? 0x11 : 0x22;`
plus `>`, `<=`, `>=`, each on values that exercise both branch directions (incl. a high-byte-differs
case so a wrong narrow vs native is caught). `dev/run.sh a16cmp` asserts a 16-bit `cmp` (opcode `cd`/
`cf`/`c9` under one rep/sep bracket) and the correct results on **both** MAME and bsnes-jg.

### Step 5 — regen patch + docs (ROADMAP, TODO, this plan).

## Verification

1. Build clean. 2. `a16cmp` shows `rep; lda; cmp; sep; bcc/bcs` and correct results on both emulators,
incl. the high-byte-differs case (proves the full 16 bits compare, not just the low byte). 3. Corpus
7/7 + all existing a16* tests green (the legalizer gate is `Pred==UGE && hasAccum16`, so default and
EQ/signed paths are untouched). 4. Patch `0002` round-trips.

## Out of scope (follow-ups, same approach)

- Equality (`== !=`): 16-bit `CmpBr` fusion in `selectBrCondImm` (Z to terminator).
- Signed (`slt/sle/sgt/sge`): the N^V 16-bit lowering.
- Compare → `select`/bool value (not a branch).
- Folding a near-abs global RHS into `CMPAbs16` is included; LHS load-fold mirrors `selectAlu16AbsLd`.
