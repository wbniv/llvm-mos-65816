# #321 native s16 — ordering-as-value branchless materialization (the 16-bit form): BUILT + measured → WON'T-DO

**One line:** The ordering-as-value boolean (`b = (a >= c)`) materializes a control-flow select-diamond; the
hypothesis was that a **16-bit** branchless tail (`lda #$0000; rol`, M16) would stay inside the ambient
sustained-16-bit run and beat the diamond without the `sep` churn that killed the 8-bit v1 form. **Built it
(candidate A: `ROLAcc16` + `G_CARRY_BOOL16` + `selectCarryBool16` + `legalizeZExt` rewrite) and measured the
real output — it REGRESSES, harder than v1.** The 16-bit form wins in *isolated leaf functions* (uge_v 25→23,
uge_arith 54→42) but loses across **every** realistic a16 program, for three structural reasons the diamond
exploits (free inversion-folding, M8-tail mode-match, GPR-not-ZP boolean). **WON'T-DO** — see the close-out
(§0a). This closes the ordering-as-value branchless track in **both** forms (8-bit v1 **and** 16-bit candidate A);
the select-diamond is the measured optimum.

**Status:** CLOSED — WON'T-DO (2026-06-21), candidate A **BUILT + measured net-negative**. Joins the *8-bit* v1
close-out in [`2026-06-21-321-native-s16-comparison-followups.md` §4b](2026-06-21-321-native-s16-comparison-followups.md).
Per the user's sharpened rule (memory `modest-gains-worth-doing`) the gain was *built*, not shelved on a hunch —
progressively cleaner forms (16-bit both-widths → 16-bit s16-only-gated) were measured and **none win on real
code**, so per "close net-negatives" (memory `close-net-negative-findings-not-defer`) it is recorded as a
*measured* "don't," not deferred. Spike lives in worktree `wt/321-cmpval` (vendor/, un-landed); **no `0002`
change ships.** The remaining (deferred, higher-effort, uncertain-upside) lever is the mode-agnostic post-REPSEP
pseudo — see §0a.

### 0a. Phase-0 RESULT — candidate A BUILT + measured → WON'T-DO (2026-06-21)

Implemented candidate A in full on `wt/321-cmpval` and rebuilt the toolchain (`clang-23` mtime advanced,
new symbols present):

- **`ROLAcc16`** pseudo (`MOSInstrLogical.td`, mirrors `RORAcc16`, `MLow=1`) — `rol a` at M16, carry→bit0.
- **`LDAImm16`** pseudo (`lda #imm16` into `Ac16`, `MLow=1`, via the multiclass-generated `LDA_Immediate16`).
- **`G_CARRY_BOOL16`** generic op (`MOSInstrGISel.td`) + **`selectCarryBool16`** (`lda #$0000; rol a; sta zp`).
- **`legalizeZExt`** rewrite: `zext(16-bit-G_SBC carry)` → `G_CARRY_BOOL16` (s16 direct; s8 via `G_TRUNC`),
  `hasAccum16`-gated. The inversion (ULT/UGT/SGE…) keeps the existing downstream `eor`.

**The materialization works** (disasm confirms `lda #$0000; rol` replacing the diamond, no crash,
`-verify-machineinstrs` clean) **and wins in ISOLATED leaves** — but **regresses every realistic program**:

| Measurement (both `+mos-a16 -Os`) | diamond | candidate A | Δ |
|---|---:|---:|---:|
| `a16cmpaudit` (compare-dense), candidate A **both-widths** | 16845 | 17499 | **+654 B** |
| `a16cmpaudit`, candidate A **gated to s16-only (direct preds)** | 16845 | 16923 | **+78 B** |
| **whole a16 corpus** (s16-only gate) | 37356 | 37696 | **+340 B, ZERO programs improve** |
| ↳ `a16scavnz` (one rol site, ZP-pressure cascade → spills) | 2296 | 2558 | +262 B |
| `uge_v` leaf (isolated) | 25 | 23 | −2 B |
| `uge_arith` = `acc*31+(a>=b)` leaf (isolated, M16 consumer) | 54 | 42 | −12 B |

**Worse than the 8-bit v1 (+262 B); even the best conservative gate (s16-only direct predicates) is +78 B and
ZERO real programs improve.** The isolated-leaf win (−12 B) appears in **no** corpus program — real
ordering-as-value booleans are always followed by mode-transitioning code, so the diamond always wins.

**Three structural reasons the select-diamond is optimal** (none fixable at legalize time):

1. **Free inversion-folding.** The diamond chooses *which arm* loads `0` vs `1`, so predicate inversion
   (ULT/UGT/SLT/SGE — ~half of orderings) costs **zero**. Any `rol`/`adc` materialization needs an explicit
   `eor #1` per inverted site (the measured `eor` 23→54, +31).
2. **M8-tail mode-match.** The diamond materializes via `ldx #0/#1` in **M8**, leaving the code in M8 — which
   matches the ambient mode *after* most boolean sites in loop-structured code. The 16-bit `rol`'s **M16** tail
   forces an extra `sep` before the following M8 housekeeping (measured `sep`/`rep` +13 each). The consumer's
   mode is **not knowable at legalize time** → no conservative gate isolates the winning case.
3. **Boolean in a GPR, not ZP.** The diamond leaves the 0/1 in `X`; candidate A's `STAImag16` consumes an
   `Imag16` zero-page slot, which **cascades into spills** in pressured functions (`a16scavnz`: +262 B from a
   single site).

**Candidate B (`ADCImm16`) is strictly worse than A** — `adc #$0000` (3 B) vs `rol` (1 B), same reasons 1–3 —
so it was **not built** (it would regress more).

**The one remaining lever (deferred, NOT pursued):** a **mode-agnostic** materialization — an `MW_None` pseudo
expanding *post-REPSEP* to ambient-width `lda #0; rol`, gated to **direct predicates only** — could neutralize
reason 2 (no extra `sep`) but **not** reasons 1 or 3, for a **rare shape + modest per-site** gain. That is
delicate `MOSInsertREPSEP` M-lattice work (the pass that has "flipped measured conclusions here") for an
uncertain, partial upside; the plan deferred it (§3 "Mode-agnostic alternative"), and it stays deferred. If the
track is ever revived, that is the entry point — and the full candidate-A implementation is preserved as a
durable patch at [`spikes/2026-06-21-321-ordering-value-candidate-a-spike.patch`](spikes/2026-06-21-321-ordering-value-candidate-a-spike.patch)
(the `wt/321-cmpval` worktree was torn down 2026-06-21 after this close-out; apply the patch over a fresh
`vendor/llvm-mos` checkout to reconstruct it).

**Verdict: WON'T-DO.** The select-diamond is the measured-optimal ordering-as-value materialization. Recorded,
not deferred (`close-net-negative-findings-not-defer`). Nothing lands in `0002`.

### 0. Handoff state (2026-06-21) — what's done, where to start

- **BUILT + measured → WON'T-DO (see §0a above).** Candidate A was fully implemented and measured: it
  regresses every realistic a16 program (a16cmpaudit +654 B both-widths / +78 B s16-only-gated; whole a16
  corpus +340 B with zero wins), worse than v1. The §3/§4/§5 plan below is retained as the *as-designed*
  spec (what was built); §0a is the *result*. Everything below §0a is historical context for the close-out.
- **Done already (on `main`, pushed):** the v1 *measurement* — `legalizeZExt`→`G_UADDE(0,0,carry)` (8-bit) —
  built, verified correct + default-byte-identical, and **closed net-negative** (the `sep` churn, §1). Its byte
  evidence is in the comparison-follow-ups plan §4b. `dev/measure-compare-surface.sh` (the audit harness) is on
  `main`.
- **The `wt/321-cmpval` worktree holds the v1 8-bit spike** in `vendor/llvm-mos/.../MOSLegalizerInfo.cpp`
  (`legalizeZExt`) — uncommitted, never landed. A pickup agent should **`git diff` it vs `main`, revert that
  block, then implement the 16-bit form (§3)**; the worktree's built toolchain still contains v1, so rebuild
  after the new edit (confirm `clang-23` mtime advances). Or start a fresh worktree per
  [`howto-feature-worktree.md`](../howto-feature-worktree.md).
- **Investigated facts (don't re-derive):** `selectAddE` asserts 8-bit (`MOSInstructionSelector.cpp:2218`), so
  `G_UADDE` can only be the churning 8-bit tail; `ADCImm16` exists (`:688`) but `selectAddE` never reaches it;
  no `ROLAcc16` (only `RORAcc16`, `:2972`); `G_UADDE` is `maxScalar(0,S8)` (`MOSLegalizerInfo.cpp:279`).

---

## 1. What we already know (measured 2026-06-21)

- The boolean materialises from a **`G_SBC` carry** (`legalizeICmp` UGE path; `def operand 1 = C`). Zext'ing it
  as a value lowers via `legalizeZExt`'s `buildSelect(carry, 1, 0)` → `MOSLowerSelect` → a control-flow
  **diamond** (`bcc; sep; lda #1; bra; sep; lda #0` ≈ 12 B tail).
- A branchless carry-tail is correct for **all** ordering predicates (UGE `adc`; ULT `adc; eor #1`; ULE/UGT
  operand-swap; SLT sign-flip; verified by disasm) and **wins per-leaf** (`uge_v` 25→19 B). Default build stays
  **byte-identical** (the rewrite is `hasAccum16()`-gated).
- **But the 8-bit form regresses in context.** `lda #0; adc #0` is M8, so its `sep #$20` cuts a 16-bit run; the
  next 16-bit op needs a `rep` back. `a16cmpaudit` (sustained M16): **+262 B** (`rep` 204→231, `sep` 212→238 ≈
  +106 B churn; `eor #1` 23→54 ≈ +62 B). c-torture (56 progs): net ≈ 0 **with** a +5 B regression.
- **Root cause of the 8-bit narrowing:** `selectAddE` (`MOSInstructionSelector.cpp:2218`) **asserts the constant
  is 8-bit** and emits the 8-bit `ADCImm`. So `G_UADDE` can only ever be the churning 8-bit tail — the wrong
  primitive. There **is** a 16-bit `ADCImm16` (`MOSInstrLogical.td:688`) but `selectAddE` never reaches it, and
  there is **no `ROLAcc16`** (only `ASLAcc16`/`LSRAcc16`/`RORAcc16`).

## 2. The principle (why we bank it despite "rare + modest")

A gain is a **priority** input, not a go/no-go (memory `modest-gains-worth-doing`, sharpened 2026-06-21). The
shape is rarer than the branch form and the per-site win is a few bytes — so this is **lower-priority**, not
**rejected**. The earlier WON'T-DO was right *about the 8-bit form* (a measured net-negative) but wrong to shelve
the *gain*: the clean form exists, so build it.

## 3. The fix — a 16-bit (mode-matched) materialization

Make the carry→bool tail **16-bit**, so in the common M16 ambient it sits inside the run (no `sep`, no churn) and
is still smaller than the diamond. Two candidate primitives (Phase 0 picks the cheapest that lands):

- **(A) A 16-bit `ROL` accumulator pseudo (`ROLAcc16`).** Materialise `lda #$0000; rol` at M16: `rol` rotates C
  into bit 0 of the 16-bit A → A16 = carry (0/1). Mirror the existing `ASLAcc16`/`LSRAcc16`/`RORAcc16`
  (`MOSShiftAcc16`, `MLow=1`, reads/`Defs` C). `legalizeZExt` emits it for `zext(sbc-carry)`; the inverted
  predicates add a 16-bit `eor #1`. **Cleanest** — `rol`-into-bit-0 is exactly the boolean, one new def line.
- **(B) Reach `ADCImm16` for the carry-tail.** `lda #$0000; adc #$0000` (`ADCImm16`, M16, carry-in = the SBC C)
  → A16 = carry. Needs a path to emit a 16-bit add-with-carry-in of 0 — `selectAddE` is 8-bit-only, so this is a
  selector/`legalizeAddSub` extension. Heavier than (A); only if (A) misbehaves.

Either keeps the materialisation in M16. In the **rare** 8-bit-ambient case (e.g. an 8-bit leaf), REPSEP brackets
it with one `rep`/`sep` — a small local loss, dominated by the common-case win (a16 is mostly-16-bit).

**Mode-agnostic alternative (deferred, not first cut):** a `MW_None` pseudo expanding *post-REPSEP* to raw
`lda #0; rol` at whatever width — wins in *both* modes, zero churn ever. But it needs a `requiredWidth`
classification + a post-REPSEP expansion that reads the ambient M; more surface than (A). Pursue only if the
16-bit form leaves a measurable 8-bit-context regression that matters.

## 4. Phase 0 — the go/no-go spike (do FIRST, on `wt/321-cmpval`)

1. **Build candidate (A)**: define `ROLAcc16`; rewrite `legalizeZExt` (`zext(sbc-carry)` → `lda #$0000` + `ROLAcc16`
   + `eor #1` for inverted) instead of the 8-bit `G_UADDE`; `hasAccum16`-gated.
2. **Measure the regime that killed v1** — `a16cmpaudit` byte size pre/post. **Gate: it must now be ≤ baseline**
   (no churn) — the whole point. Plus the per-leaf wins must survive (`uge_v` etc. still < diamond).
3. **Realistic net** — byte-diff the c-torture in-scope sample + the a16 corpus: **net-positive, and crucially
   ZERO common-shape regressions** (a16cmpaudit neutral-or-win). If any common shape regresses, (A) isn't the
   form — try (B) or the mode-agnostic pseudo, or stop.
4. **Default gating** — default build byte-identical (the `hasAccum16` gate).

**If Phase 0 shows net-positive with no common-case regression → implement §5. Else iterate the primitive or
record the second WON'T-DO.**

## 5. Implementation + verification (the bar)

- Land (A) [or (B)]: the `ROLAcc16` pseudo (`.td` + `requiredWidth`/REPSEP classification + the carry-liveness
  invariant: nothing clobbers C between the `cmp`/`G_SBC` and the `rol`), the `legalizeZExt` rewrite, the
  inverted-predicate `eor`. `hasAccum16()`-gated.
- **The 4-way differential is mandatory** (this changes value-producing codegen): host == default@MAME ==
  a16@MAME == a16@bsnes-jg (== xy16), over a new `examples/65816/a16cmpval.c` + `dev/a16cmpval.sh` that asserts a
  spread of ordering-as-value results (all 6 predicates, signed+unsigned, reg/mem/imm operands) against the host
  oracle, with a disasm gate (`rol`/no select-diamond). The branchless materialisation MUST compute the same
  boolean — a wrong carry sense = miscompile.
- No regression: a16 suite green; `corpus` 7/7; `fuzz --gen csmith 200 …` 0 mismatch/crash; `torture 60` no FAIL;
  `-verify-machineinstrs` clean; **byte-diff the a16 corpus → net-positive, zero common-shape regression.**
  Regenerate `0002`, round-trip, no foreign hunks.

## 6. Bookkeeping

- On land: flip the §4b WON'T-DO note in the comparison-follow-ups plan to "banked via the 16-bit materialisation
  — see this plan"; promote/append the M2 TODO. `dev/measure-compare-surface.sh` regression-guards the surface.
- Worktree `wt/321-cmpval`: reuse it (it holds the v1 8-bit spike — replace with the 16-bit form). Commit; push
  when asked.

## 7. References

- v1 (8-bit) measurement + WON'T-DO: [`2026-06-21-321-native-s16-comparison-followups.md` §4a/§4b](2026-06-21-321-native-s16-comparison-followups.md).
- Code: `legalizeZExt` (the rewrite site), `legalizeICmp` UGE/`G_SBC` (carry = def 1), `selectAddE`
  (`MOSInstructionSelector.cpp:2218`, the 8-bit assert), `MOSShiftAcc16`/`ASLAcc16` (`MOSInstrLogical.td:929`,
  the 16-bit-shift template to mirror for `ROLAcc16`), `ADCImm16` (`:688`), `requiredWidth`
  (`MOSInsertREPSEP.cpp`, the M-width classifier). Ambient-mode lesson: [[a16-codegen-mostly-16bit-mode]].
