# #321 — native s16 equality-as-value: the full one-REP-bracket compare-and-materialize

**Date:** 2026-06-18
**Status:** **WON'T-IMPLEMENT** (Phase 0 spike, 2026-06-18) — both candidate materializations are measured
regressions: Option A (reuse-existing-ops, carry→diamond) **+14 B** and Option B (explicit branchless
`rol`/`adc` tail) **+16…+28 B** on every shape. The existing select-diamond is near-optimal for
equality-as-value (it fuses the compare into a `CmpBr`, which branchless materialization forgoes).
Investigated in throwaway worktrees (`wt/321-eqval-spike`, `wt/321-eqval-optb`), no `vendor/` change shipped.
See **§Phase 0 — RESULTS** (both options measured, with tables, disasm, and root cause). (Mirrors the
indirect-s16-load-bytewise investigation that also landed WON'T-DO.)
**ROADMAP:** step 5 (M2) · **TODO:** M2 "16-bit comparison follow-ups" item (c) — the *full native compare*,
the last deferred piece of that bullet, now dispositioned.

## Phase 0 — RESULTS (2026-06-18, spike measured → WON'T-IMPLEMENT)

Spiked **Option A** (branchless, reuse existing native ops) in an isolated worktree seeded from main's
toolchain (`vendor/llvm-mos` + `build/` copied; one-TU incremental rebuilds, 11–25 s each). The scratch edit
(`MOSLegalizerInfo::legalizeICmp`, EQ native **value** path only, gated `NativeS16 && !isNZUseLegal`):
replaced `buildNZSelect(Z)` with `X = LHS ^ RHS` (native EOR → Imag16) then `C of SBC(0, X) = (0 ≥ᵤ X) =
(X == 0) = (LHS == RHS)`, copied to `Dst`.

**Measured (`+mos-a16 -Os`, `.text.main` bytes, `-verify-machineinstrs` clean):**

| shape | residency | diamond (baseline) | branchless (spike) | Δ |
|-------|-----------|-------------------:|-------------------:|----:|
| `a16eqval`  | both-global | 104 | 118 | **+14 B** |
| `a16eqvalc` | computed    | 121 | 135 | **+14 B** |
| `a16eqvalp` | indirect    | 154 | 168 | **+14 B** |

**Branchless loses on every shape. Three root causes, in descending importance:**

1. **The backend has no branchless flag→byte materialization.** The carry copied to `Dst` *itself* lowers to
   a control-flow **diamond** — confirmed in the spike disasm: `bcc $22; ldx #1; stx; bra $24; stz`
   (offsets 0x1a–0x24). So "branchless" never materializes branchlessly; the XOR approach merely adds the
   value computation (`eor; sta; lda #0; cmp`) *on top of an unchanged diamond*.
2. **Equality's Z is not rotatable.** There is no "rotate Z into A" — only carry rotates. Synthesizing a
   rotatable carry for `==` requires first computing the difference/XOR **value** (an extra native ALU op +
   an Imag16 stash), which costs more than the one-branch diamond it would replace. (The *first* spike
   attempt — reuse `Sbc.getReg(0)` as the difference — failed to compile: the EQ `G_SBC` selects as a
   **flag-only compare** (`CMPAbs16`/`CmpBrAbsAbs16`), so its difference register is never defined →
   `Reading virtual register without a def`. The difference simply isn't available without a real value op.)
3. **The i16 `0` constant clumsily materializes** into an Imag16 pair (`ldx #0; stx; ldx #0; stx` prologue)
   rather than an `lda #0` immediate — worth ~8 B of the +14, but removing it still leaves a ~+6 B
   regression from cause #2.

**Why the diamond is already near-optimal:** the prior v1/v2/v3 work folds the operands into the compare
(`lda abs; cmp abs` / `lda zp; cmp zp`), the Z flag is read by **one** branch, and the two arms store `0`/`1`
directly (`ldx #1; stx` / `stz`). For equality there is nothing cheaper to reduce Z to a byte.

**Option B (an explicit `lda #0; rol`/`adc` branchless tail) — MEASURED 2026-06-18 (was "predicted"; the
user asked for proof).** Built the branchless tail *without* a new pseudo by reusing existing machinery:
`selectAddE` already lowers `G_UADDE` → `adc`, so the EQ value path emits `X = LHS^RHS`; `Ceq = C of
SBC(0,X) = (X==0)`; `byte = G_UADDE(0,0,Ceq)` → `txa; adc #0` (carry→bit0). The tail **is** genuinely
branchless — disasm shows `txa; adc #$0` with **no** `bcc`/`beq` 0/1 diamond (tail check: `adc` present,
`bcc=0`). Result — a **larger** regression than even Option A:

| shape | diamond | Option A (carry→diamond) | **Option B (rol/adc tail)** |
|-------|--------:|-------------------------:|----------------------------:|
| `a16eqval`  | 104 | 118 (+14) | **120 (+16 B)** |
| `a16eqvalc` | 121 | 135 (+14) | **149 (+28 B)** |
| `a16eqvalp` | 154 | 168 (+14) | **175 (+21 B)** |

The disasm shows exactly why (`a16eqval`, first `a==b`): `rep; lda a; eor b; sta X; lda #0; cmp X; sep;
txa; adc #0; sta` — the **tail `txa; adc #0` is cheap (3 B)**, but **the branchless path forgoes the `CmpBr`
compare-fusion the diamond exploits.** The diamond fuses `lda; cmp` straight into the branch (one
`CmpBrAbsAbs16`); the branchless path must instead form the difference value (`eor`), stash it, and run a
*standalone* `lda #0; cmp X` to generate a carry — because equality's Z isn't rotatable (cause #2), you
cannot branch-free without first materializing `X = LHS^RHS`. So Option B pays for **both** a non-fused
compare **and** the value computation, while saving only ~6 B on the materialization itself. Net: a clear,
measured regression. A hand-built `CmpSel*16` pseudo would hit the *same* two costs (it still needs `eor` +
a carry-generating compare, and a materialize can't use the Z-branch fusion), so it was **not** built — the
`G_UADDE` proxy + the disasm-revealed mechanism settle it. Shipping a guaranteed-≥-diamond mechanism for a
measured regression violates governing lessons #2/#3 (gate only where it wins — it wins nowhere). **Not
pursued.** (Proof experiment:
[prove-option-b plan](2026-06-18-prove-option-b-rol-tail-materialization-for-native.md).)

**Disposition:** equality-as-value stays on the existing select-diamond (already operand-folded and
near-optimal). The branch-use EQ path, and the v1/v2/v3/imm/task7 gated value forms, are unchanged and remain
the right answer. Worktree + scratch branch removed; no `vendor/`/patch change. The rest of this document is
the original design contract, retained for the record.

---

## The one-sentence ask

`b = (a == c)` consumed as a **value** (not a branch): replace the current control-flow **materialization
diamond** with a **single one-REP/SEP-bracket compare-and-materialize** that produces the 0/1 without
splitting the basic block — beating the diamond on the cases that already go native, and (stretch) cheap
enough to widen the gate to operand shapes that currently decline.

## Where we are (read this before assuming there is nothing left)

A great deal of EQ-as-value has **already landed** — five gated forms, all verified, all on the
**branch-fused select path**:

| form | what goes native | plan |
|------|------------------|------|
| v1 | an **indirect-load** operand (`*p == c`) | `2026-06-16-321-native-s16-eq-gated-impl.md` |
| v2 | both operands **Imag16-resident / computed** (`(a+b) == (c+d)`) | `2026-06-17-321-native-s16-eq-v2-computed-imag16-lhs.md` |
| v3 | both **global** (`g1 == g2`) → `lda abs; cmp abs` | `2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md` |
| imm | **global vs immediate** (`g == 0x1234`) → `lda abs; cmp #imm` | `2026-06-17-321-native-s16-eq-imm-constant-through-merge.md` |
| task7 | **computed vs global** (`(a+b) == g`) → `lda zp; cmp abs` | `2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md` |

The earlier prologue **regression** (an s16 load consumed only by `G_UNMERGE` round-tripping through `A16`)
is **FIXED** (byte-wise load, `legalizeLoadStore16`, commit `7c0fe56` —
`2026-06-16-321-s16-load-unmerge-bytewise.md`). So today EQ-as-value is **at parity-or-better with default
everywhere**; this plan is purely an *optimizing* follow-up, not a regression fix.

### How the value materializes **today** (the thing we want to replace)

In `MOSLegalizerInfo::legalizeICmp`, the `ICMP_EQ` case (grep `// #321 native s16 equality (branch-fused)`):

```cpp
auto Sbc = Builder.buildInstr(MOS::G_SBC, {CmpTy/*=s16 when NativeS16*/, ...}, {LHS, RHS, CIn});
Register Z = Sbc.getReg(4);
if (!isNZUseLegal(Dst, MRI))      // value use (store/zext), not a branch
  Z = buildNZSelect(Z, Builder);  // <-- builds G_SELECT(Z, -1, 0)
Builder.buildCopy(Dst, Z);
```

`buildNZSelect` (grep the symbol) emits `G_SELECT(Z, -1, 0)`. That select is lowered by **`MOSLowerSelect`**
into a **`G_BRCOND_IMM` control-flow diamond**, and `selectBrCondImm` fuses the 16-bit `G_SBC` into a
`CmpBr{Imag16,Imm16,AbsAbs16,AbsImm16,ImagAbs16}` pseudo *inside the diamond's condition*. The comment at
the call site says it outright: *"the materialization **diamond** loads 0/1."* So the value path **reuses the
entire `CmpBr*16` family** — the per-residency compare is already optimal; the **overhead is the diamond**
(two arms that load `0`/`1`, an unconditional `bra`, and a PHI join — plus a basic-block split that
`MOSInsertREPSEP` must re-establish mode across).

`isNZUseLegal` (grep) is what distinguishes branch-use (returns true → `Z` feeds the terminator directly, no
select) from value-use (returns false → the diamond). Branch-use EQ is already fully native and is **out of
scope** here.

### What is NOT covered today (the gap this plan targets)

1. **The diamond itself**, on every already-native value case (v1/v2/v3/imm/task7). A branchless or
   single-pseudo materialization that stays in one REP/SEP bracket should be ≤ the diamond and removes the
   BB split.
2. **Operand shapes that currently DECLINE** and stay on the 8-bit `cpx;cmp` chain — `register == register`,
   `computed == param`, plain locals. The v1/v2 spikes measured the *blanket* native form **+8 B worse**
   for these (the operand must be spilled to `Imag16` for `CMPImag16`, which the tight 8-bit `cpx;cmp`
   avoids) — **but that measurement charged the diamond materialization**. If the new materialization is
   cheap enough, some may flip to a win. **Re-measure; do not assume.**
3. **`x == 0` / `x != 0` as a value** stays on the 8-bit byte-OR (`G_CMPZ`). task7 §2 measured the *native*
   `== 0` value at **+5 B** — but via `rep; lda imag; sep`-sets-Z **+ diamond**, NOT the branchless
   materialization below. So this is genuinely unmeasured for the new mechanism and is a spike sub-case.

## The two candidate materializations (the spike decides)

For unsigned `short` operands, `(l == c)` ⟺ `(l ^ c) == 0` and `(l != c)` ⟺ `(l ^ c) != 0`. Both candidates
compare in 16-bit mode (Z/result reflect all 16 bits — a `sep` to 8-bit before the zero-test would see only
the low byte and miscompile `0x0100`-type differences).

### Option A — **branchless, reuse the existing native XOR** (strongly preferred if it wins)

Lower the value as a native 16-bit **EOR** (which *already* has full operand-residency folds —
`EORImm16`, `eor abs`/`eor zp` via the mixfold/bitchain work) followed by a fixed **nonzero→bool** tail:

```
rep #$20
lda  $l            ; or `lda abs $l`         — reuses the existing EOR operand fold
eor  $r            ; A16 = l ^ c   (==0 iff equal)   [EORImag16 / EORAbs16 / EORImm16]
cmp  #1            ; C = (A16 >= 1) = (A16 != 0) = (l != c)
lda  #0
rol  a             ; A16 = C  →  0x0001 (l!=c) / 0x0000 (l==c)
;  for ==:  eor #1  (16-bit)  →  0x0001 (l==c) / 0x0000
sta  $dst          ; native 16-bit store of the bool (high byte already 0)
```

**Why this is attractive:** the operand half (`lda`/`eor` with abs/zp/imm folds) is **entirely existing
machinery** — every residency case (computed, both-global, indirect, global-vs-imm, computed-vs-global) is
already handled by the native ALU fold path, *for free*. The only **new** primitive is the residency-
independent **`s16-nonzero → i1` tail** (`cmp #1; lda #0; rol [; eor #1]`). That serves `(l == c)` (via the
xor) **and** `x == 0` / `x != 0` directly. **No new `CmpSel*16` pseudo family.** Fully branchless: no BB
split, one REP/SEP bracket end-to-end.

Likely integration: in `legalizeICmp`'s native-EQ **value** path, instead of `buildNZSelect(Z)`, build
`X = G_XOR(LHS, RHS)` and feed `X` to a small **nonzero-to-bool** lowering. The tail's `cmp #1; lda #0; rol`
needs a target representation — either a tiny pseudo `G_NZ16_TO_BOOL` (one operand, Imag16-resident; expands
post-RA to the three-instruction tail, mirroring how `expandCmpBr16` builds its sequence) or, if it can be
expressed with existing selectable generic ops that already lower to `rol`/`cmp #imm`, no new pseudo at all.
Resolve in Phase 0.

### Option B — **`CmpSel*16` pseudo family** (the original deferred sketch; fallback)

Mirror the `CmpBr*16` family but end in a materialization instead of `BR`:
`CmpSel{Imag16,Imm16,AbsAbs16,AbsImm16,ImagAbs16}`, selected by the **same** residency-fold helpers
`selectBrCondImm` uses, expanded by an `expandCmpSel16` that **shares the `LDA $l; CMP $r` front-end with
`expandCmpBr16`** (refactor that function into a shared front-end emitter + a tail) and ends in either
`beq/bne; lda #1/stz` (a local branch — still control flow, just not a cross-block diamond/PHI) or the same
`cmp #1; lda #0; rol` branchless tail as Option A. This is **5 pseudos + a generic carrier op + selection +
expansion** — *substantial*, and largely redundant with Option A's reuse of the EOR folds. Pursue **only if
Option A's branchless tail loses** to the diamond but a fused-pseudo form wins.

**Decision rule:** Option A unless the spike shows the EOR detour (the extra `eor` vs `cmp` and the
`cmp #1; lda #0; rol` tail) loses to a fused `CmpSel*16`. Default to the smaller change.

## Phase 0 — the spike (MEASURE before building anything real)

Per governing lesson #1 (measure, don't assume) and the measurement methodology in `docs/agent-handoff.md`
(toggle **only** the feature gate on the **same** C shape; decide on **bytes**; measure in **16-bit-ambient**
context, not isolated leaves).

1. **Capture the current (diamond) bytes** for the already-native value cases: build, then
   `llvm-objdump -d --mcpu=mosw65816` + `--section-headers` on the existing
   `examples/65816/a16eqval.c` (both-global), `a16eqvalc.c` (computed), `a16eqvalp.c` (indirect). Record
   per-`.text.main` size and the diamond shape (`CmpBr*16` + `bra` + two 0/1 arms). This is the baseline to
   beat. *(These files already exist and pass — they are the toggle-off reference.)*

2. **Prototype Option A's nonzero→bool tail** behind a **scratch gate** (one shape, e.g. the computed
   `a16eqvalc`): emit `G_XOR(LHS,RHS)` + the `cmp #1; lda #0; rol [; eor #1]` tail (hand-built pseudo or
   existing-op lowering) for the value use. Rebuild (**confirm `clang-23` mtime advanced** — the stale-build
   gotcha), disasm, diff bytes vs step 1 in **16-bit-ambient** code (not a leaf — wrap in the
   sustained-`M=0` pattern the other a16eqval tests use).

3. **Go/no-go gate.** Tabulate, per residency case, **native-materialize bytes vs diamond bytes** (and vs
   the 8-bit `cpx;cmp` chain for the currently-declined register/param cases). Proceed to Phase 1 **only if**
   the new materialization is **≤ the diamond on the already-native cases AND meaningfully wins somewhere**
   (either shrinks the native cases or flips a declined case). If it is a wash-or-worse everywhere →
   **WON'T-IMPLEMENT**: write the measurements into this plan's Verification as evidence, revert the scratch,
   confirm the tree is byte-identical to baseline, and close the TODO item as investigated. (This is the
   honest, lesson-#1 outcome and is explicitly acceptable.)

4. **`x == 0` / `x != 0` sub-spike** (cheap, do it in the same build): re-measure the value `(x == 0)` /
   `(x != 0)` with the branchless tail vs the current 8-bit byte-OR (`a16eqvalz.c` is the ready shape).
   task7's +5 B was a *different* mechanism; this may differ. Fold the result into the gate decision.

## Phase 1 — implement the winning materialization (only if Phase 0 says go)

Assuming **Option A**:

- **`MOSLegalizerInfo::legalizeICmp`** (grep `NativeS16Eq`, `buildNZSelect`): in the `ICMP_EQ` native value
  path (`NativeS16Eq && !isNZUseLegal(Dst)`), replace `buildNZSelect(Z)` with the XOR + nonzero→bool
  lowering. Leave the **branch-use** path (`isNZUseLegal` true) and all **ordering** (`UGE`/`SLT`) paths
  exactly as they are.
- **The nonzero→bool primitive** (`G_NZ16_TO_BOOL` pseudo or existing-op lowering, per Phase 0): one
  Imag16-resident s16 input → i1/i8 bool. If a pseudo: define in `MOSInstrPseudos.td` next to `CmpBr*16`
  (`Defs = [C, A16, NZ]`, `HasAccum16`), expand in `MOSInstrInfo.cpp` (mirror `expandCmpBr16`'s post-RA
  A16-based emission) to `CMPImm16 #1; LDImm16 #0; ROL A16 [; EORImm16 #1]`. Wire the post-RA dispatch and
  any `analyzeBranch`/`getBranchDestBlock` only if it introduces a terminator (Option A does **not** — it is
  branchless, so no terminator plumbing).
- **`!=`** is `negateInverseComparison` → EQ already (grep the `ICMP_NE` switch arm at the top of
  `legalizeICmp`), so `b = (a != c)` rides the same path with the final `eor #1` dropped (or added — confirm
  the polarity at the inversion point).

If **Option B**: mirror the `CmpBr*16` family per its section above; refactor `expandCmpBr16` into a shared
front-end first (a clean, separately-verifiable no-op refactor — byte-identical CmpBr output).

## Phase 2 — widen the gate to currently-declined shapes (only if Phase 0 showed a flip)

If the cheaper materialization flips `register == register` / `computed == param` from regression to win,
extend `NativeS16Eq`'s disjunction (grep the `const bool NativeS16Eq =` block) to admit them — **but keep it
conservative (governing lesson #2): a misclassification must only ever miss a win, never cause a
regression.** Each newly-admitted shape needs its own measured win in the table. If nothing flips, leave the
gate exactly as-is (the new materialization still benefits the already-native cases via Phase 1).

## Gating discipline (do not skip — this is where this family has bitten before)

- **The change must not touch the default (non-`+mos-a16`) build.** Gate every new behavior **and every
  operand canonicalization / helper predicate** on the **same predicate that enables the feature** —
  `NativeS16Eq` (= `hasAccum16() && Type==s16 && Pred==ICMP_EQ`), never a looser operand-shape test. The
  seed-42 miscompile (`2026-06-18-321-seed42-legalizeicmp-swap-fix.md`) was exactly this: an EQ-canonical
  swap guarded only by `ComputedVsGlobal` (no `hasAccum16`/`Pred==EQ`) reversed a `<`/`>` compare in the
  **default** build. The differential fuzzer guards the default build — a leak shows up as `default@MAME ≠
  host`. **Run `fuzz 50 1` and treat any default-build mismatch as a release blocker.**
- **`== 0` stays excluded** unless the Phase 0 sub-spike proves the branchless tail wins it (keep the
  existing `!RHSIsZero` guard otherwise).

## Verification (the contract — fill raw output + PASS/FAIL during implementation)

The bar is the **differential**: host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean (`docs/agent-handoff.md`).

1. **Phase 0 measurement table** (the go/no-go evidence): per residency case, diamond bytes vs
   native-materialize bytes vs 8-bit-chain bytes, in 16-bit-ambient context. Paste the `--section-headers`
   sizes and the disasm of one representative case. *(PASS = a measured win meeting the Phase 0 gate, or a
   documented WON'T-IMPLEMENT with the numbers.)*

2. **New / extended micro-test** — `examples/65816/a16eqvalv.c` + `dev/a16eqvalv.sh` (template:
   `examples/65816/a16eqval*.c` + `dev/a16eqval*.sh`): exercises the residency matrix (computed, both-global,
   indirect; plus register/param if Phase 2 widened the gate) consumed as **values**. Asserts (a) a
   `corpus_result` equal across **host == default == +mos-a16** on **MAME + bsnes-jg**, and (b) a **disasm
   gate** for the new shape — the branchless materialize present (`rol` after the native `eor`/`cmp`, **no**
   diamond `bra` over a 0/1 load) where the gate fires; **no** `cpx`/`cpy` 8-bit chain. Wire into
   `dev/run.sh`.

3. **`-verify-machineinstrs` clean** on the new shapes (the `mos-clang … -mllvm -verify-machineinstrs -c`
   host command in `docs/agent-handoff.md`); clean exit.

4. **Non-breaking — full regression sweep.** a16 suite all-PASS
   (`for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done`), corpus `7/7`
   (`dev/run.sh corpus`), differential fuzzer `dev/run.sh fuzz 50 1` → `50/50, 0 mismatch, 0 new-crash,
   0 error` (**guards the default build**). The already-native EQ-as-value tests (`a16eqval`, `a16eqvalc`,
   `a16eqvalp`, `a16eqvalg`, `a16eqvalmg`) stay green and — if Phase 1 shrank them — have their disasm gates
   updated to the new materialize shape.

5. **Patch round-trips.** `dev/regen-patch.sh` → `0002` round-trips; `git diff --cached --name-only` is
   exactly this task's files (never `vendor/`, a foreign patch, or `docs/transcripts/`); sanity-check `0002`
   absorbed no foreign hunks (`grep -c` a foreign symbol).

## Risks & honest priors

- **The diamond may already be near-optimal.** `selectBrCondImm` fuses the compare into the branch, so the
  diamond is `CmpBr*16 + bra + 2 small arms + PHI` — the branchless tail (`eor + cmp #1 + lda #0 + rol`) is a
  similar byte count. The win, if any, is likely **small + structural** (no BB split → fewer cross-block
  `rep`/`sep` fixups, better for chained booleans). That is consistent with the deferred note's own verdict
  — *"Substantial; modest win on a rare pattern."* Governing lesson #3 says a modest compiler win is still
  worth doing **if genuine** — but only if Phase 0 confirms it. **WON'T-IMPLEMENT is a respectable result
  here**, exactly as it was for `2026-06-16-321-indirect-s16-load-bytewise.md`.
- **Scope creep into a 5-pseudo family.** Option A's reuse of the existing EOR folds is the guard against
  this; only fall to Option B (the `CmpSel*16` family) if forced by measurement.
- **Polarity bugs** (`==` vs `!=`, the final `eor #1`) — the regression micro-test exercises **both** senses
  across the residency matrix; the fuzzer covers values broadly.

## TODO / handoff updates (same commit as the plan)

- Update TODO.md M2 item (c): point the *"full native compare … still deferred"* clause at this plan
  (`docs/plans/2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md`); on completion, move to
  Done with the measured outcome (win + bytes, or WON'T-IMPLEMENT + the table).
- No `docs/agent-handoff.md` backend-nav change until a pseudo actually lands (then add `CmpSel*16` /
  `G_NZ16_TO_BOOL` to the pseudo list next to `CmpBr*16`).
</content>
</invoke>
