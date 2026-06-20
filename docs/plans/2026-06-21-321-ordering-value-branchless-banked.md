# #321 native s16 — bank the ordering-as-value branchless win (the *right* way: 16-bit materialization)

**One line:** The ordering-as-value boolean (`b = (a >= c)`) is worth banking (it's a real per-site win, and on
a compiler any gain is a priority, never a go/no-go) — but the win has to be taken with a **materialization that
matches the ambient M-mode** so it never forces a `sep`. The first attempt used an **8-bit** tail (`lda #0;
adc #0`) which churns `rep`/`sep` in the **common** sustained-16-bit context (the measured +262 B `a16cmpaudit`
regression). The fix is a **16-bit** materialization (`lda #$0000; rol`-equivalent, M16) — a16 code is mostly
16-bit ([[a16-codegen-mostly-16bit-mode]]), so a 16-bit tail stays in the run → no churn → win where it matters.

**Status:** PLANNED (2026-06-21). Supersedes the **WON'T-DO** verdict in
[`2026-06-21-321-native-s16-comparison-followups.md` §4b](2026-06-21-321-native-s16-comparison-followups.md):
that closed the *8-bit* implementation as net-negative; this plan banks the *same win* via the correct
(16-bit / mode-matched) materialization. Per the user's sharpened rule (memory
`modest-gains-worth-doing`): a clean gain is never shelved for being rare/modest — if the naive impl
regresses, **build the form that banks it cleanly.** Compiler change → worktree `wt/321-cmpval` (exists).

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
