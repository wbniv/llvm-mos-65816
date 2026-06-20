# #321 native s16 comparison follow-ups — close-out + the ordering-as-value branchless materialization

**One line:** The native 16-bit compare surface is **measured ~complete** (2026-06-21): every predicate/operand
shape emits the native `rep; lda; cmp` path **except** register-resident equality, which is intentionally
byte-wise (`cpx; cmp`, optimal). The one **unexplored** win is materializing an **ordering** result *as a value*
(`b = (a < c)`) via a branchless carry-tail instead of the current select-diamond — distinct from the
**rejected** equality rol-tail because ordering's `cmp` yields the carry directly (no "compute the value first"
cost). Measure it; land if it wins; close the track either way.

**Status:** PLANNED (2026-06-21). Supersedes the open M2 "native s16 — 16-bit comparison follow-ups" TODO item
(whose header overstates the residual — see §2). Implementation is a compiler change → throwaway worktree off
`main` per [`docs/howto-feature-worktree.md`](../howto-feature-worktree.md).

> **Honesty note.** This is a **measurement-gated close-out**, not a big feature. The empirical state below shows
> the compare-optimization track is ~95% done; the deliverable is (a) one narrow, well-motivated candidate win
> and (b) a definitive audit that closes the remaining surface with evidence rather than leaving a vague
> "follow-ups" item open. Per governing lesson #3 a modest amplified win is worth doing; per the project's
> measure-first + close-net-negatives doctrine, a measured loss is an answer (don't do it), not a backlog item.

---

## 1. Background — how s16 compares are lowered today

`MOSLegalizerInfo::legalizeICmp` canonicalizes **all 10 ICMP predicates down to three primitives** — `EQ`, `UGE`,
`SLT` — then lowers each natively under `+mos-a16`:

- **`NE`/`ULT`/`SGE`** → `negateInverseComparison` (negate of `EQ`/`UGE`/`SLT`).
- **`ULE`/`UGT`/`SLE`/`SGT`** → `adjustConstRHS` then `swapComparison` to a canonical form.
- **`SLT`** → rewritten to **`ULT` on sign-flipped operands** (`a^0x8000 <ᵤ b^0x8000`), reusing the native 16-bit
  `EOR` + the unsigned carry path. **No N^V flag handling** — signed ordering reduces to unsigned.
- **`UGE`** → kept un-narrowed, lowered via a 16-bit **`G_SBC`** (the C-flag path); `selectSbc16`
  (`MOSInstructionSelector.cpp`) emits one `rep; lda; cmp; sep`, folding the RHS operand into `CMPImm16` /
  `CMPAbs16` / `CMPIndir16` / `CMPImag16` as available.
- **`EQ`** → native (one `rep; lda; cmp; sep` producing **Z**, selected via `CmpBrImag16`/`CmpBrImm16`/the abs-fold
  `CmpBr*Abs*16` family) **when** (a) the result feeds a branch (Z fuses into the terminator), **or** (b) an
  operand is a non-absolute indirect s16 load (`isIndirectS16Load`, the EQ-as-value win), **or** (c) a single-use
  foldable absolute s16 load (`isFoldableAbsS16Load`, v3). **Otherwise EQ narrows to the 8-bit byte chain.**

What already landed (Done): native unsigned-ordering slice 1 (`[321-native-16bit-compares]`), native equality
`==`/`!=` (`[…-equality-compares]`), native signed ordering via sign-flip (`[…-signed-compares]`), the abs/indirect
operand folds (`[…-compare-abs-operand-fold]`, `[321-native-16bit-indexed-compares]`), and the EQ-as-value v2
(computed/Imag16 LHS, `fd6b281`) + v3 (abs-fold globals, `efce68f`). The EQ-as-value **prologue regression** is
fixed (byte-wise load for `G_UNMERGE`-consumed s16, `legalizeLoadStore16`), and the **full-native EQ materialize**
is **WON'T-DO** (Option A reuse-ops **+14 B**, Option B rol-tail **+16…+28 B** — measured 2026-06-18).

## 2. Measured current state (2026-06-21) — the residual is ONE byte-wise case

Probed `+mos-a16 -Os` codegen across the predicate × operand-shape × value/branch matrix (host disasm; see §4 for
the reproducible audit). **Native = `rep; lda; cmp`; byte-wise = `cpx; cmp`.**

| Shape | Value (`b = …`) | Branch (`if(…)`) |
|---|---|---|
| `EQ`, both operands **register-resident** (`x==y`, params in `$a:$x`) | **byte-wise** `cpx;cmp` | native |
| `EQ`, operand from memory / computed / immediate (`g1==g2`, `(x+y)==K`, `a==imm`) | **native** | native |
| `ULT`/`UGE`/`ULE`/`UGT` (unsigned), any operand shape | **native** | native |
| `SLT`/`SLE`/`SGT`/`SGE` (signed), any operand shape | **native** (sign-flip `eor #$8000`) | native |

**So the "remaining" of the TODO header collapses to exactly one cell:** register-resident **equality as a value**
(`eq_param`: `cpx $hi; bne; cmp $lo; bne; … diamond`). That is **intentional and optimal** — the LHS sits in
`$a:$x`, so the tight `cpx;cmp` (4 B, no `rep/sep`, no `Imag16` spill) beats forcing a native compare (which must
spill the register operand to `Imag16`; measured a regression, and the full-native materialize is the WON'T-DO
above). Measured: `eq_param` = **22 B** byte-wise vs `ult_param`/`uge_param` = 25 B native (different predicates,
but confirms byte-wise equality is not bloated).

**Unsigned/signed ordering *as a value*** is native for the **compare** but materializes the boolean with a
**control-flow select-diamond** (`bcc $X; lda #0; … ; lda #1`). That diamond is the **one unexplored cost** (§3).

## 3. The candidate win — branchless carry-tail for ordering-as-value

### 3.1 Why this is NOT the rejected equality rol-tail

The 2026-06-18 Option-B proof rejected the branchless `lda #0; rol`/`adc` tail **for equality** because equality
has **no flag that is the result**: Z isn't rotatable, so the pseudo "must first compute the difference/XOR
value, whose cost exceeds the rol-tail savings → net ≥ diamond" (`prove-option-b-…` §conclusion). That plan used
`UGE`-as-value only as a *control* ("expect a diamond, not `adc`/`rol`") — it **never built or measured a rol-tail
specifically for ordering.**

**Ordering is structurally different:** `cmp` (and the `SBC` carry path) produces **C = (a ≥ᵤ b)** directly — the
carry **is** the `UGE` result. There is no difference/XOR to compute first. So the exact cost that killed the
equality rol-tail is **absent** here. The same applies to **signed** ordering (it reduces to `ULT` on sign-flipped
operands → also ends in a carry) and to all the negate/swap variants (they reduce to `UGE`/`ULT`).

### 3.2 The mechanism (no new pseudo)

The proof plan already established the cheap path: `selectAddE` (`MOSInstructionSelector.cpp` ~2117) lowers
`G_UADDE`/`G_SADDE` → `ADCImm`/`ADCImag8`, so building **`G_UADDE(0, 0, orderingCarry)`** in the legalizer (or
select-lowering) should select to **`lda #0; adc #0`** = carry→bit0 = the branchless boolean. Concretely, where
the canonical `UGE` lowering today hands its carry to the boolean-materialization (the select-diamond), instead
feed that carry into `G_UADDE(0,0,C)` and use its result as the i1/i8 value — **only when the comparison result is
consumed as a value** (not a branch; a branch reads the flag directly and must stay a fused terminator).

Estimated saving: the proof plan put the rol-tail materialization at **~5 B** vs the diamond. Realizing it for
ordering (where the value-compute cost is zero) is the unrealized win. Modest per-site, **amplified across every
program built with the toolchain** (lesson #3).

### 3.3 The risks to measure (this is gated on measurement, not assumed)

1. **Mode juggling.** The carry is set in 16-bit-ambient mode (`rep #$20`); the `adc #0` tail and the i1→i16
   zero-extend of the boolean must land in the right width without re-bracketing that eats the savings. The
   `G_UADDE(0,0,C)` could re-enter 16-bit `ADC` (wrong/costly) — verify it selects the 8-bit `lda #0; adc #0`.
2. **Carry liveness.** The `sep #$20` between the compare and the tail must not clobber C (it doesn't — `sep`
   only touches M/X), but the scheduler/REPSEP placement must keep C live to the `adc`; verify in MIR.
3. **It might still lose.** If the backend's select-lowering already folds the diamond well, or the extra
   `G_UADDE` node perturbs scheduling, the net could be ≥ diamond. **If measured net-negative or net-zero, CLOSE
   it as won't-do with the byte evidence** (do not ship a blanket regression; do not leave it "deferred").
4. **Frequency.** `b = (a < c)` (ordering result stored/returned, not branched) is less common than the branch
   form. Phase 0 counts its occurrences in the corpus + c-torture so the win is weighed against the effort.

### 3.4 Alternatives considered

- **A dedicated `CmpSel*16` pseudo** with an explicit `rol` tail — heavier than reusing `G_UADDE`/`selectAddE`;
  only revisit if the `G_UADDE` route fails to select branchlessly.
- **Touching the register-resident equality cell** — out of scope; measured optimal byte-wise + full-native is
  the standing WON'T-DO.

## 4. Phase 0 — the audit + measurement gate (do this FIRST; it may close the item outright)

Run on a throwaway worktree; host-side compile + disasm (no emulator needed for the byte audit).

1. **Exhaustive compare-surface audit.** Extend the §2 probe to the full matrix: {`EQ,NE,ULT,ULE,UGT,UGE,
   SLT,SLE,SGT,SGE`} × {both-reg, reg-vs-mem, reg-vs-imm, mem-vs-mem, computed-LHS, indirect-load} × {value,
   branch}. Disasm each `+mos-a16 -Os`; tabulate native vs byte-wise + byte count. **Confirm the only byte-wise
   cell is register-resident equality** (or surface any other gap for separate triage). Script it as
   `dev/measure-compare-surface.sh` (a durable keeper).
2. **Frequency scan.** Count ordering-as-value sites (`G_UADDE`/select-from-`G_SBC`-carry consumed as a value, not
   a branch) across `examples/65816/*.c` + the c-torture in-scope set. Quantify the addressable win.
3. **Byte-diff probe for §3.** On 4–6 representative ordering-as-value shapes (`b=(a<c)`, `b=(a>=c)`,
   `r=(sa<sb)`, `b=(a<0x1234)`), build the `G_UADDE(0,0,C)` tail and byte-diff vs the select-diamond, in
   **16-bit-ambient context** (not isolated leaves — lesson #1). **This is the go/no-go gate for §3.**

**If Phase 0 shows the tail does not win** (or wins too rarely to matter): record the measurement, mark §3
**won't-do**, and the plan's deliverable is the audit + the close-out (§6). **Do not implement.**

## 4a. Phase 0 results — step 1 audit (RAN 2026-06-21, `dev/measure-compare-surface.sh`)

Full 10-predicate × {RR,RI,MM,RM,CMP}-value + branch matrix, `+mos-a16 -Os`, host disasm:

```
EQ/NE   value: BYTEWISE for register-LHS (RR/RI/RM, the tight cpx;cmp); NATIVE for MM; NATIVE for CMP.
ULT..UGE value: NATIVE for ALL operand shapes (RR/RI/MM/RM/CMP).
SLT..SGE value: NATIVE for ALL operand shapes (sign-flip eor #$8000).
ALL value cells materialise the boolean with a bcc/bcs SELECT-DIAMOND.   branch cells: NATIVE, fused.
```

Two refinements vs the §2 sketch, both *widening* the picture:
1. **No branchless materialisation exists anywhere today.** (An early probe mis-read the `adc` of a computed
   `(x+y)` operand as a tail; the actual materialisation is *always* the diamond — confirming the 2026-06-18
   "no branchless flag→byte path exists" premise.) So §3 **builds** the tail; it does not extend an existing one.
2. **The §3 target is broad:** *every* ordering-as-value cell — 8 predicates × 5 operand shapes ≈ all of the
   ordering matrix — currently spends a diamond. EQ-as-value stays diamond (Z non-rotatable, the standing
   won't-do) and register-LHS EQ stays byte-wise (optimal). So §3 is the **only** open lever, and it is wide.

This justifies the §3 spike (step 3): a broad target + the mechanism (`selectAddE`/`G_UADDE`) already present.

### Phase 0 step 3 — byte-diff (RAN 2026-06-21): **GO**, +3…6 B/site

The boolean materialisation is already a CFG diamond at `-print-before=instruction-select`
(`G_SBC`→carry `%c`; `G_BRCOND_IMM %c`→two BBs→`G_PHI 1/0`) — i.e. `zext(i1 sbc-carry)` lowered through
`G_SELECT`→`MOSLowerSelect`. Measured the win in **real bytes** (not estimated): take the compiler's diamond
asm, hand-write the branchless `rol`-tail, byte-count both.

```
uge_v  (return x>=y, carry IS the result):
  diamond:    rep;lda;cmp; bcc; sep;lda #1; bra; sep;lda #0; ldx #0; rts   = 25 B
  branchless: rep;lda;cmp; lda #$0000; rol; sep; ldx #0; rts              = 19 B   → −6 B (−24%)
ult_v  (return x<y, inverse carry): branchless + `eor #$0001`             = 22 B   → −3 B (−12%)
```

`lda #$0000; rol` (16-bit) puts the carry into bit 0 = the boolean, in 4 B, replacing the ~12 B diamond tail;
the inverted predicates (ULT/ULE/SGE…) pay +3 B for `eor #1` but still win. **Clean win** for a single
ordering-value materialisation (strictly smaller; touches neither the branch path — which reads the carry
via `G_BRCOND_IMM` directly — nor equality, whose Z is non-rotatable). **Step 2 (frequency):** ordering-as-value
is real but **less common than the branch form**, so the *aggregate* is modest — but per lesson #3 a clean
3–6 B/site win amplified across every toolchain build is worth landing. **Verdict: GO** (clean, broad, modest).

The implementation (§5) is therefore unblocked: a `hasAccum16()`-gated rewrite of `zext(i1 sbc-carry)` (the
ordering-value materialisation, single-use, not a branch) into `G_UADDE(0,0,carry)` (+ an `eor #1` for the
inverted predicates), placed before `MOSLowerSelect` forms the diamond — measured net-positive, zero
regression, or it doesn't ship.

### 4b. Implementation BUILT + measured (2026-06-21): **NET-NEGATIVE → WON'T-DO**

Built it (the §4a/§5 rewrite, in `legalizeZExt` on `wt/321-cmpval`) and measured the REAL output — which
**reverses the §4a "GO."** The §4a byte-diff was on **isolated leaf functions**; the built compiler, measured in
**realistic 16-bit-ambient context, regresses** — the exact regime-flip governing lesson #1 warns about.

- **Correct + the leaf win is real:** all ordering predicates go branchless and verify-by-inspection correct
  (UGE `cmp;adc`; ULT `cmp;adc;eor #1`; ULE/UGT operand-swap; SLT sign-flip). `eq_v` untouched. Default build
  **byte-identical 75/75** (gating holds). Per-leaf: `uge_v` 25→19 (−6), `ult_v` 25→21 (−4), etc.
- **But it regresses in realistic context.** The 8-bit `lda #0; adc #0` tail **breaks the 16-bit run** with its
  `sep #$20`, forcing extra `rep`/`sep`. `a16cmpaudit` (compare-dense, sustained M16): **+262 B** (rep 204→231,
  sep 212→238 ≈ +106 B churn; `eor #1` 23→54 ≈ +62 B inversions). c-torture (56 progs, realistic): **net ≈ 0**
  — 1 win −6 B, **1 regression +5 B** (`20000224-1`); the value shape is rare, so the aggregate is a wash *with
  regressions*.
- **Why not gate/rescue:** the win-vs-regression hinges on the **ambient mode** (does the tail's `sep` break a
  run?), which is **not visible at legalize time** — no clean conservative gate exists. The only churn-free form
  is a **16-bit** `rol`-tail (no `sep`), but the selector narrows the `adc` to 8-bit and forcing 16-bit needs a
  new MOS pseudo — high-effort for a **rare** value shape whose realistic aggregate is already ~0.

**Verdict: WON'T-DO** (correct but net-negative in the regime that matters; rare shape; clean gating infeasible).
The select-diamond is the better ordering-value materialisation in sustained 16-bit code. Recorded, not
deferred (per "close net-negatives"). **This closes the native s16 comparison track**: the surface is native +
optimal everywhere it pays (the byte-wise register-resident equality + the diamond materialisation are both the
measured optimum); the one open lever was measured worse-in-context and is shut. `dev/measure-compare-surface.sh`
is the durable audit harness.

> **Follow-up (2026-06-21): the 16-bit `rol`-tail above was BUILT and ALSO measured net-negative.** The
> "only churn-free form is a 16-bit `rol`-tail" sentence motivated a dedicated spike
> ([`2026-06-21-321-ordering-value-branchless-banked.md`](2026-06-21-321-ordering-value-branchless-banked.md))
> — a real `ROLAcc16`/`LDAImm16`/`G_CARRY_BOOL16` materialization (`lda #$0000; rol a`, M16). It **regresses
> harder than v1**: `a16cmpaudit` **+654 B** (both-widths) / **+78 B** (even gated to s16-direct-only), whole
> a16 corpus **+340 B with zero programs improving**. The 16-bit `rol` tail is *not* in fact churn-free in
> real code: the diamond folds predicate inversion for free (the `rol` needs an explicit `eor`), the diamond's
> M8 tail matches the ambient mode after most boolean sites (the `rol`'s M16 tail forces a `sep`), and the
> `rol` routes the boolean through an `Imag16` ZP slot (the diamond keeps it in `X`, avoiding spill cascades).
> So the **ordering-as-value branchless materialization is now WON'T-DO in BOTH forms (8-bit v1 + 16-bit
> candidate A)** — the diamond is the measured optimum, full stop. See that plan's §0a for the close-out.

## 5. The fix (only if Phase 0 §3 measures a win) + verification

- Land the `G_UADDE(0,0,C)`-tail in `legalizeICmp`/select-lowering, **gated** so it fires only for an
  ordering result **consumed as a value** (every use is a value use, none a `G_BRCOND_IMM`) and only under
  `hasAccum16()` — default 8-bit codegen byte-identical, and the branch path's fused terminator untouched.
- Regression guard: a new `examples/65816/a16cmpval.c` + `dev/a16cmpval.sh` asserting `corpus_result` over a
  spread of ordering-as-value shapes, host == default == `+mos-a16` (== `+mos-xy16`) on both emulators, with a
  disasm gate (`adc #0`/no select-diamond present).
- **The bar (4-way differential):** host == default@MAME == a16@MAME == a16@bsnes-jg, `-verify-machineinstrs`
  clean. Then: a16 suite green; `corpus` 7/7; `fuzz --gen csmith 200 …` 0 mismatch/0 crash; `torture 60` no FAIL;
  byte-diff the a16 corpus to confirm the net win and **zero regressions** (a blanket loss that regresses a common
  shape to win the value sub-case is wrong — gate it). Regenerate `0002`, round-trip, no foreign hunks.

## 6. Likely outcome & close-out

Most probable: §3 lands as a small, gated, net-positive optimization (ordering-as-value branchless materialization),
**or** measures net-neutral/negative and is closed with evidence. **Either way, this plan closes the native s16
comparison track:** update the M2 "comparison follow-ups" TODO item to Done, recording the definitive surface map
(everything native except the optimal byte-wise register-resident equality), the §3 disposition, and the standing
WON'T-DO (full-native EQ materialize + register-resident equality native). No vague "follow-ups" item remains.

## 7. References

- Current code: `MOSLegalizerInfo::legalizeICmp` (the EQ/UGE/SLT canonicalization + the `hasAccum16` gates),
  `MOSInstructionSelector::selectSbc16` (the `CMP*16` operand folds), `selectAddE` (~2117, the `G_UADDE` →
  `ADCImm`/`ADCImag8` path that gives the branchless tail for free).
- The rejected equality rol-tail (why ordering is different):
  [`2026-06-18-prove-option-b-rol-tail-materialization-for-native.md`](2026-06-18-prove-option-b-rol-tail-materialization-for-native.md)
  + [`2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md`](2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md).
- Prior compare landings: [`2026-06-14-321-native-16bit-compares.md`](2026-06-14-321-native-16bit-compares.md),
  [`2026-06-15-321-native-16bit-equality-compares.md`](2026-06-15-321-native-16bit-equality-compares.md),
  [`2026-06-15-321-native-16bit-signed-compares.md`](2026-06-15-321-native-16bit-signed-compares.md),
  [`2026-06-15-321-native-16bit-compare-abs-operand-fold.md`](2026-06-15-321-native-16bit-compare-abs-operand-fold.md),
  [`2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md`](2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md).
- Build/test mechanics, the differential bar, the QUIET-box rule: [`docs/agent-handoff.md`](../agent-handoff.md).
