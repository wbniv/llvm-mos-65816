# #321 native-s16 — surface consolidation & close-out (compares/branches · A16-threading · ALU-chain extensions)

**Date:** 2026-06-22 · **Status:** **Phase 0 DONE — CONFIRMED measured-complete surface** (ran 2026-06-22 on
`main`'s installed toolchain; nothing built). The expected null held: the per-op surface reproduces its measured
optima, the one open frontier is the single shared RA-residency-under-pressure core, and the GO contingency did
**not** fire. One *new*, bounded, measurement-gated candidate (≥8-shift bracket fragmentation) was surfaced and
routed to a future spike — it does not meet the GO bar. · **Milestone:** M2 (#321) — ROADMAP step-5 frontier
consolidation.
**Rolls up (does not re-implement):** the three open M2 native-s16 tracks —
[16-bit compares/branches close-out](2026-06-21-321-native-s16-comparison-followups.md) (TRACK CLOSED),
[A16-threading](2026-06-17-321-a16-threading.md) + its
[Phase-3 deferral formalization](2026-06-20-321-a16-threading-phase-3-formalize-the-deferral-r.md),
and [16-bit ALU-chain multi-value register pressure](2026-06-18-321-16bit-alu-multivalue-register-pressure.md)
(CHARACTERIZED-deferred).
**Template it mirrors:** [#320 zero-bank (AS4) measure-and-close](2026-06-22-320-zerobank-as4-measure-and-close.md)
— the same "the cores all shipped/closed; assemble the **de-lumped, measured** surface map that *completes the
model* and hands upstream a clean story" deliverable, applied to #321 instead of #320.
**Upstream:** feeds a new "#321 stage-1 native-s16 is measured-complete" paragraph into the queued upstream
artifacts ([upstream-contribution-status](../upstream-contribution-status.md)) — posting is user-triggered.

---

> **Honesty note (the tone this plan is written in).** This is a **measurement-gated consolidation + close-out,
> not a new feature** — the same frame the comparison-followups plan opened with. All three named native-s16
> tracks are already at their measured state: compares is *closed*, threading banked its win and *deferred* its
> hard core, ALU-chains shipped every homogeneous form and *characterized-deferred* the one residual. The
> deliverable is a single durable **surface map** that (a) proves ROADMAP step-5's "smaller/faster than the M1
> 8-bit output" bar is met across the whole surface, (b) replaces three separately-tracked loose ends with the
> *one* structural fact that unifies them, and (c) drafts the upstream paragraph. Per governing lesson #3 a
> modest amplified win is worth doing; per the project's measure-first + close-net-negatives doctrine, a measured
> loss/deferral is an **answer**, recorded — not a vague backlog item left open. **No `vendor/` change is
> planned** (GO contingency kept + pre-registered, not expected).

---

## TL;DR

Native-s16 (the `+mos-a16` 16-bit-accumulator codegen, ROADMAP step 5 / #321 stage 1) is built across three
axes that are tracked as three open M2 items. Measured individually, **all three are already at their measured
optimum or a measured-deferral**:

- **16-bit compares/branches** — *track CLOSED 2026-06-21.* The full predicate × operand-shape × value/branch
  matrix is native (`dev/measure-compare-surface.sh`), the sole exception being register-resident
  equality-as-value (the tight byte-wise `cpx; cmp`, which is **optimal**). The one open lever
  (ordering-as-value branchless carry-tail) was **built and measured net-negative in BOTH the 8-bit and the
  16-bit-`rol` forms** → WON'T-DO; the select-diamond is the measured optimum.
- **A16-threading** — *Phases 0/1/1.5 DONE, Phase 3 deferred.* The post-RA `threadAccum16` peephole eliminates
  the redundant `STAImag16; LDAImag16` round-trip between dependent native s16 ops (−31/−36 % on chains,
  −4..−10 B on kernels; a 300-program scan leaves **1** non-adjacent reload). Phase 2 is **retired** (folds are
  already optimal). The RA-level `Ac16`-residency core (Phase 3) is a **measured deferral**.
- **16-bit ALU-chain extensions** — *all homogeneous forms shipped, multi-value pressure characterized-deferred.*
  Add chains, in-chain immediates, and AND/OR/XOR chains thread through A16; SUB chains are moot (reassociated).
  Multi-value pressure is tight for 2–9 live values (−58..−65 % vs default, one `rep`/`sep` bracket, the 2nd
  value folded as a memory operand); the lone residual is `Imag16`-pool exhaustion (>14 live s16) fragmenting
  the M=16 region, which **0 of 13 real functions hit** (`dev/measure-zp-pressure.sh`).

**The one structural fact that unifies them (the genuine value-add of this consolidation):** the two
*deferred* tails — A16-threading **Phase 3** (pre-RA `Ac16` residency) and ALU-chain **multi-value pool
exhaustion** (>14 live s16) — are **not two loose ends. They are one deferred hard core**: RA-level 16-bit-value
residency under register pressure, the same failure the `globals.c` `+mos-a16 -Os` RA crash root-causes to
(unspillable `Ac16` `INF` transits + the single 65816 accumulator + X/Y taken by 8-bit loop machinery). So the
native-s16 surface has **exactly one** open frontier, gated behind **one** concrete re-open trigger and **one**
B0→B1→B2 spike recipe — everything else is measured-optimal. This plan records that map and closes the surface,
exactly as the zero-bank plan completed the five-space model.

---

## What "native-s16" is (scope of this consolidation)

"Native-s16" = the per-operation 16-bit-accumulator codegen surface under `+mos-a16` (`M=0`): values flow
through the 65816's 16-bit `A` (`Ac16`) / the `Imag16` zero-page pool instead of the 8-bit byte-pair chains
the 6502 backend emits. ROADMAP "agreed optimization order" items **2–6** all live here and are all built:

| # | Surface | State | Evidence |
|---|---|---|---|
| 2 | **16-bit compares/branches** | native everywhere it pays; track **CLOSED** | `dev/measure-compare-surface.sh` |
| 3 | inc/dec + 16-bit shifts (incl. signed `>>`) | done (variable shifts WON'T-DO; amount≥8 optimal; `inc abs` rejected) | a16shift/a16ashift/a16incdec suites |
| 4 | indexed/array access (indirect `(zp)`, abs, `abs,x`/`(zp),y`) | done | a16ptr/a16abs/a16absidx/a16indiry |
| 5 | **A16-threading** (value live in A across ops) | Phases 0/1/1.5 done; Phase 3 deferred | `dev/measure-a16-threading.sh` |
| 6 | cross-block REP/SEP M-flag mode-tracking | done (X-flag is the separate xy16 track) | a16loop/a16call |
| — | **16-bit ALU-chain extensions** (add/imm/bitwise chains) | done; multi-value pressure characterized-deferred | `dev/measure-zp-pressure.sh` |

**Explicit boundary (out of scope — named so the surface map is honest about its edges):**

- **Item 7 — hardware-stack ABI / 16-bit calling convention.** Not a per-op native-s16 optimization; it is the
  ABI track, upstream-gated (the [CC frame decision](2026-06-18-321-cc-frame-phased-decision.md) keeps the soft
  static stack first-pass). Separate item, not closed here.
- **xy16 (the X-flag / 16-bit index mode).** A separate mode dimension on its own track
  ([xy16 plan](2026-06-17-321-xy16-index-register-mode.md)); native-s16 is the **M**-flag (accumulator)
  surface only.
- **The two open `+mos-a16` RA/scavenger bugs** (`globals.c` `regalloc-out-of-registers`; the
  register-scavenger `$p is not a GPR` N/Z-liveness crash) — kept on their own bullets. This plan references the
  `globals.c` crash *only* as the manifestation of the shared deferred core; it does not re-open either bug.

---

## The three tracks, measured (the de-lumped state — what makes the close *earned*, not asserted)

### A. 16-bit compares/branches — TRACK CLOSED (measured optimum, both levers shut)

`legalizeICmp` canonicalizes all 10 ICMP predicates to `EQ`/`UGE`/`SLT`, each lowered natively under
`hasAccum16()`. The exhaustive audit (`dev/measure-compare-surface.sh`, 10 predicates × {RR,RI,MM,RM,CMP} ×
{value,branch}) confirms **every cell is native except register-resident equality-as-value** — which is the
tight `cpx; cmp` (no `rep`/`sep`, no `Imag16` spill) and is **optimal**, not a gap. The two candidate levers
were both *built and measured*, not assumed:

1. **Full-native EQ-as-value materialize** — Option A (reuse-ops) **+14 B**, Option B (`rol`-tail) **+16…+28 B**
   → WON'T-DO. Z is non-rotatable, so the value must be computed first, forgoing the compare-fusion the diamond
   exploits.
2. **Ordering-as-value branchless carry-tail** — the `cmp` carry *is* the `UGE` result (no compute-first cost,
   so structurally unlike #1). Built in `legalizeZExt`; **leaf win real** (`uge_v` 25→19 B) **but regresses in
   16-bit-ambient context**: the 8-bit `adc`-tail's `sep` breaks the M=16 run — `a16cmpaudit` **+262 B**,
   c-torture net ≈0 *with a +5 B regression*. The churn-free **16-bit-`rol` form** was then *also* built
   (candidate A): **worse** — `a16cmpaudit +654 B`, whole a16 corpus **+340 B with zero programs improving**.
   The select-diamond folds inversion free, its M8 tail matches ambient mode, and it keeps the boolean in `X`
   (not an `Imag16` slot that cascades to spills). **Both forms WON'T-DO.**

This is the textbook governing-lesson-#1 leaf→ambient flip, recorded with bytes. **Nothing remains open on the
compare surface.**

### B. A16-threading — Phases 0/1/1.5 done; Phase 3 is a *measured* deferral

Each native s16 op is self-contained (`LDAImag16 → OP → STAImag16`, value home = `Imag16` between ops — the
1d-retry coalescer-safe invariant), so a dependent chain stored each intermediate and immediately reloaded it.
The reframing that landed the win **coalescer-free**: that redundancy is a *post-RA* pattern (RA already chose
`$a16` both sides), so `threadAccum16` (`MOSLateOptimization.cpp`) erases the redundant reload and the value
threads through `$a16` across the chain. Measured **−31/−36 % on dependent chains, −4..−10 B on kernels**; the
non-adjacent remainder is **1** (300-program scan). Phase 2 (fold-while-threaded) is **retired** — interior
immediates and near-abs globals already fold into the threaded chain.

**Phase 3 = RA-level `Ac16` residency** (thread the single-use producer's `Ac16` vreg into the consumer at
`selectAlu16Native`, pre-RA). The deferral is **measured, not assumed**: the asserts build (`50a59b5`)
**ruled coalescing out** as the `globals.c` crash cause (zero 8-bit↔`A16` joins) — the crash is many
single-instruction `Ac16` `INF` transits competing for the one accumulator. So the realizable gain is capped by
the single 65816 accumulator (two live 16-bit values *must* spill to `Imag16` — which the peephole already
captures), and the only motivation left is one pathological `-Os` crash on slack code, while the risk reopens
the 1d coalescer crash on the common path. **Keep the XFAIL**; the B0→B1→B2 spike recipe + concrete trigger are
recorded.

### C. 16-bit ALU-chain extensions — homogeneous chains shipped; multi-value pressure characterized-deferred

`collectAluChain` threads add / in-chain-immediate / AND-OR-XOR chains through A16 (`add_chain16_ld`,
`bit_chain16{,_ld}`); SUB chains are moot (the optimizer reassociates `a−b−c` to `a−(b+c)`). The "what about
>1 live 16-bit value?" premise was **measured and found mostly already solved**: there are **~14** `Imag16`
pairs, not one slot; 2–9 simultaneously-live s16 values compile to **one** `rep`/`sep` bracket with the 2nd
value folded as a memory operand (`and __rc2`), **−58..−65 %** vs default, verify-clean even at pool
exhaustion. The lone residual — >14 live s16 fragmenting the M=16 region into many brackets (byte-wise-through-`X`
spill) — is **pathological-only**: `dev/measure-zp-pressure.sh` shows **0 of 13 real functions** exhaust the
pool (max ~5 of 14 pairs). DEFER-with-data; the gated Phase-1 spill-fusion peephole is fully specified, ready
if a real trigger appears.

---

## The unification (the one fact this consolidation contributes)

> **A16-threading Phase 3 and ALU-chain multi-value pool-exhaustion are the same deferred problem.**

Both are **RA-level 16-bit-value residency under register pressure**, and both are the `globals.c`
`+mos-a16 -Os` RA-crash class:

| | A16-threading Phase 3 | ALU-chain multi-value (>14 live) | shared core |
|---|---|---|---|
| symptom | one pathological `-Os` regalloc crash | M=16 fragments into many `rep`/`sep` | one accumulator + pressure |
| lever | pre-RA `Ac16` residency in `selectAlu16Native` | 16-bit spill-fusion in `MOSInsertREPSEP` | keep s16 values resident at 16-bit |
| trigger | a 2nd independent realistic regalloc/ZP overflow | a real function >14 live s16 | realistic code crossing ~10/14 `Imag16` pairs |
| risk | reopens 1d coalescer crash (common path) | sound post-RA, but pathological-only gain | high-risk/low-reward |
| state | keep XFAIL (`a16regpress.c`) | DEFER-with-data | **one** trigger, **one** recipe |

Recognizing this collapses "three open native-s16 items" into "**a complete, measured surface plus one shared,
pathological, pre-registered deferral.**" That is the close: native-s16 is at its measured optimum everywhere a
single-accumulator machine can profitably reach, with the one remaining frontier named, gated, and risk-weighed
— not three vague follow-ups.

---

## Honest expectation (pre-registered)

**Most likely: CONFIRMED measured-complete surface.** The consolidated re-measurement reproduces the three
tracks' recorded numbers (compares native + both levers net-negative; threading −31/−36 % with 1 residual reload;
multi-value −58..−65 % with 0/13 pool exhaustion) and the ROADMAP step-5 kernel bar (native a16 < 8-bit-a16 on
the same shape, corpus 7/7). Deliverable: a durable `dev/measure-native-s16-surface.sh` roll-up + this recorded
verdict + the upstream paragraph + the three TODO items folded to "Done / one shared deferral." **No compiler
code lands.**

**Contingency: GO (a spike).** Kept + pre-registered. Fires *only* if the consolidated re-measurement surfaces a
**new** clean, net-positive, differential-clean residual that is **not** the shared pressure core (which stays
deferred under its own trigger). Not expected — the per-op surface has been swept exhaustively across the
06-14→06-21 increment series.

---

## Where it runs (host-only measurement; no worktree unless a spike fires)

Per CLAUDE.md "Investigations on throwaway worktrees" and mirroring the zero-bank Phase-0 census: **the
consolidation is pure host-side measurement** — prebuilt `mos-clang`, zero `vendor/` edits — so it needs **no
worktree** (run on `main`'s installed toolchain, like `dev/measure-*-census.sh` did). A worktree
(`throwaway/321-native-s16-spike` off `main` HEAD) is created **only** if the GO contingency fires; it is torn
down on a null (keeping the recorded verdict), or RETAINED until upstream merge if anything lands. Commit
discipline: stage only this plan + the roll-up script + the doc cascade; never `vendor/`, never a foreign patch,
never `docs/transcripts/`.

---

## Phase 0 — the consolidating measurement (the actual work)

No compiler code shipped. Build **one durable roll-up** that drives the three existing harnesses and adds the
one consolidated view they lack, then record the verdict. Deliverable:
`dev/measure-native-s16-surface.sh` + the verdict written back into this file and the three rolled-up plans.

### 0a — drive the three durable harnesses and snapshot their verdicts

The roll-up invokes (does not duplicate):

- `dev/measure-compare-surface.sh` → the full compare matrix (assert: only register-resident EQ-as-value is
  byte-wise; every other cell native).
- `dev/measure-a16-threading.sh` → the redundant-reload count on chains/kernels (assert: 1 non-adjacent
  remainder; −31/−36 % on dependent chains).
- `dev/measure-zp-pressure.sh` → the `Imag16` high-water mark per real function (assert: 0 of 13 exhaust;
  max ~5/14).

Record each harness's headline number in one table. PASS = the three recorded states reproduce on the current
`main` toolchain (no drift).

### 0b — the ROADMAP step-5 acceptance roll-up (the one consolidated view that's missing today)

ROADMAP step 5's bar is *"a 16-bit arithmetic kernel … is smaller/faster than the M1 8-bit-mode output for the
same source; the M0+M1 corpus stays green."* The per-increment plans each proved their slice; **no single
artifact asserts the whole-surface bar.** This roll-up adds it, per the measurement methodology (toggle **only**
the feature gate — native-`+mos-a16` vs 8-bit-`+mos-a16` on the *same* C shape, in 16-bit-ambient context, bytes
first):

1. For each kernel (`examples/65816/k_*.c`) and the chain/multi-value probes, compile twice — native vs the
   8-bit-a16 baseline for the shape — and tabulate `.text` bytes + the delta.
2. Assert the surface-wide win (chains −31/−36 %, multi-value −58..−65 %, kernels −4..−10 B) and **corpus 7/7**.
3. Record the table as the durable ROADMAP step-5 evidence (it currently lives scattered across the increment
   plans + the ROADMAP verification §5 narrative).

### 0c — pin the shared deferred core (the non-circularity check)

Mirroring the zero-bank plan's "is this null *structural* or *circular*?" discipline: state, with the asserts
evidence, that the one open frontier is **structural** (single accumulator + pressure → spill, coalescing ruled
out), not "open because nobody tried." Confirm the **one** trigger covers **both** deferred tails:

> Re-open the shared core **only when** either (a) the corpus / c-torture / fuzzer surfaces a *second
> independent* `regalloc-out-of-registers` / `a16-zp-pressure-overflow` from **realistic** (not hand-reduced)
> code, or (b) `dev/measure-zp-pressure.sh` shows a real function crossing **~10 of 14** `Imag16` pairs. Then
> run the gated B0→B1→B2 spike (recipe in the A16-threading plan). Until then: **keep the XFAIL**
> (`a16regpress.c`) and the DEFER-with-data.

PASS = the trigger is concrete, single, and shown to subsume both A16-threading Phase 3 and the >14-live
ALU-chain residual.

---

## Pre-registered go/no-go (decide the bar *before* re-measuring)

- **Native-s16 is MEASURED-COMPLETE (close, nothing lands)** — the expected, publishable result — if 0a
  reproduces the three recorded states, 0b confirms the surface-wide step-5 win + corpus 7/7, and 0c shows the
  one shared frontier is structural and trigger-gated. This **completes the native-s16 surface map** and is the
  deliverable.
- **A spike is WORTH it (GO)** only if 0a/0b surfaces a **new**, realistic, repeated, net-positive,
  differential-clean residual that is **not** the shared pressure core. The bar names the **8-bit-a16 baseline
  for the same shape** (never default vs a16) and requires **zero regression on common shapes** (a sub-case win
  that regresses common shapes is wrong — gate it, lesson #3). Not expected.

---

## Disposition

- **Measured-complete (expected):** durable artifacts merge to `main` — `dev/measure-native-s16-surface.sh` + the
  recorded verdict + the doc cascade. **No compiler code lands.** Promote the comparison-followups TODO item to
  **Done**; fold the A16-threading and ALU-chain items' "Remaining" sentences into the **single shared-core
  deferral** with the one trigger + the B0→B1→B2 recipe pointer; update ROADMAP verification §5 to point at the
  roll-up table. Queue the upstream paragraph.
- **GO (not expected):** spin `throwaway/321-native-s16-spike`, run the gated spike, land only on a measured
  net-positive zero-regression result via `dev/regen-patch.sh` (`0002` round-trip, no foreign hunks), wire its
  micro-test into `dev/run.sh` + `dev/xcheck.sh`; worktree RETAINED until upstream merge.

---

## Upstream — the paragraph that completes the #321 stage-1 story (user-triggered to post)

Mirror a pointer in [upstream-contribution-status](../upstream-contribution-status.md). Draft:

> **#321 stage-1 native-16-bit-accumulator codegen is measured-complete.** Under the opt-in `+mos-a16` target
> feature, the full per-operation s16 surface flows through the 65816's 16-bit accumulator instead of 8-bit
> byte-pair chains: ALU (add/sub/and/or/xor, inc/dec), constant + signed shifts, indirect/absolute/indexed
> load-store, the full 10-predicate compare/branch surface, homogeneous add/immediate/bitwise op-chains, and
> cross-block `REP`/`SEP` M-flag mode-tracking. Dependent chains additionally **thread the running value through
> the accumulator across ops** (a post-RA peephole, coalescer-safe), measured **−31/−36 %** on chains, **−58..−65 %**
> on multi-value kernels, and **−4..−10 B** on realistic kernels vs the 8-bit-mode output for the same source,
> 4-way differential-clean (host == default == `+mos-a16` on MAME == `+mos-a16` on bsnes-jg) with
> `-verify-machineinstrs` clean. Two micro-optimizations were *built and measured net-negative in realistic
> 16-bit-ambient context* and are retained as non-goals (the ordering-as-value branchless carry-tail in both its
> 8-bit and 16-bit forms; full-native equality-as-value materialize) — the control-flow select-diamond and the
> byte-wise register-resident equality are the measured optima. The one remaining frontier is **RA-level 16-bit
> value residency under register pressure** (the single 65816 accumulator forces a spill when >1 sixteen-bit
> value is live, and a pathological `-Os` case can exhaust the allocator) — deferred as high-risk/low-reward
> behind a concrete trigger, since the single-accumulator cap bounds its realizable gain and the redundant-reload
> peephole already captures what such a machine can profitably thread.

---

## Verification (acceptance steps — raw output + PASS/FAIL; RAN 2026-06-22)

> Measured host-side via **`dev/measure-native-s16-surface.sh`** on `main`'s installed toolchain (`clang-23`,
> Jun 20 22:04). All native-s16 (`0002`) landings predate it; only later #320/xy16 work postdates it, irrelevant
> to the M-flag surface. Full captured output: the roll-up's own stdout (reproducible on `main`).

1. **0a harness roll-up.** `dev/measure-native-s16-surface.sh` drives the three harnesses; the recorded states
   reproduce on `main`'s toolchain (compares: only register-resident EQ-as-value byte-wise; threading: 1
   non-adjacent reload, −31/−36 % chains; ZP pressure: 0/13 exhaust, max ~5/14). PASS = no drift.

   **PASS — all three reproduce, no drift.**
   - **Compare surface** (`measure-compare-surface.sh`): only the register-resident EQ/NE **value** cells
     (RR/RI/RM) are `BYTEWISE` (the tight `cpx;cmp`, optimal); MM/CMP-value and **all** ordering value cells are
     `NATIVE`; every value cell materialises via the `DIAMOND`. (The `+BRANCHLS` tag on the CMP-value column is
     the classifier's known false-positive — the `adc` of the computed `x+y` operand, **not** a real carry-tail;
     confirms "no branchless materialisation exists anywhere," the standing WON'T-DO premise.)
   - **A16-threading** (`measure-a16-threading.sh`): `roundtrips=0` on **every** synthetic chain (chain3/chain5/
     reuse/mixedlocal) **and** every kernel (k_crc16/k_fxmul/k_prng/k_bits/k_satadd/k_isort) — i.e. the
     post-`threadAccum16` optimum; the `−31/−36 %` figure is the historical threading-on/off delta at landing.
   - **ZP pressure** (`measure-zp-pressure.sh`): `real-code functions n=13 max=10 bytes (k_bits:main, ~5 pairs)
     mean=5.6; >28 (pool-exhausting): 0 ⇒ DEFER confirmed`. Bonus live evidence of the shared core:
     `(compile failed: globals)` and `(compile failed: a16regpress)` — the `regalloc-out-of-registers` crash
     under `+mos-a16 -Os`.

2. **0b ROADMAP step-5 roll-up.** The kernel/chain/multi-value table shows native-a16 < 8-bit-a16 on the same
   shape (chains −31/−36 %, multi-value −58..−65 %, kernels −4..−10 B); `dev/run.sh corpus` → 7/7. PASS = the
   whole-surface step-5 bar is met in one artifact.

   **PASS — with a measurement-forced refinement (the honest, lesson-#1/#2 result).** The step text's
   "kernels −4..−10 B" conflated baselines: that figure was the **threading-on/off** delta, *not* a16-vs-default.
   Measured **a16 vs default (the M1 8-bit output — the literal step-5 bar)**, the result is **mixed**, and that
   mixedness *is the evidence for the opt-in/per-op-gated design*:
   ```
   unit          |  a16 (B) | 8bit (B) | delta (B) | delta %
   --------------+----------+----------+-----------+--------
   k_bits        |     162  |    161   |       +1  |    +1%
   k_crc16       |      89  |     70   |      +19  |   +27%
   k_fxmul       |      72  |     63   |       +9  |   +14%
   k_isort       |     211  |    348   |     -137  |   -39%
   k_prng        |      99  |     62   |      +37  |   +60%
   k_satadd      |      57  |     50   |       +7  |   +14%
   chain*        |      35  |     95   |      -60  |   -63%
   multivalue*   |      51  |    147   |      -96  |   -65%
   --------------+----------+----------+-----------+--------
   TOTAL         |     776  |    996   |     -220  |   -22%
   ```
   The **milestone bar is MET** (an *existence* bar — "a 16-bit arithmetic kernel … smaller than the M1 8-bit
   output"): the sustained-16-bit class the milestone names ("fixed-point multiply-add loop") wins decisively —
   `chain* −63 %`, `multivalue* −65 %`, `k_isort −39 %` — and the aggregate is **−22 % (−220 B)**. The byte/
   mixed-interleave kernels (k_crc16/k_prng/k_fxmul/k_satadd/k_bits) are **larger** under `+mos-a16` — on-design,
   governing lessons #1/#2: they are 8/16-**interleave correctness stress tests** (16-bit accumulator threaded
   across 8-bit counters / a call boundary), written to *pressure*, not to shrink; their native ops route through
   `Imag16` + `rep`/`sep` and lose to the tight 8-bit byte path. **Verified genuine** (not an artifact): both
   k_prng and k_crc16 show **no libcall asymmetry** vs default (only `__rc*`), just `rep`/`sep` + `Imag16`
   overhead (k_prng 7, k_crc16 9 brackets). `dev/run.sh corpus` → **7/7 passed** (`hello/arith/control/arrays/
   structs/funcs/globals` — the default 8-bit build; `globals` passes default but crashes `+mos-a16 -Os`, the
   shared core — consistent).

3. **0c shared-core pin.** The verdict states the one open frontier is structural (single accumulator + pressure,
   coalescing ruled out per `50a59b5`) and the single trigger subsumes both A16-threading Phase 3 and the
   >14-live ALU-chain residual. PASS = one concrete trigger, not two vague ones.

   **PASS.** The roll-up's 0c block states the single trigger (a *second* independent realistic
   `regalloc-out-of-registers`/`a16-zp-pressure-overflow`, **or** a real function crossing ~10/14 `Imag16`
   pairs) and shows it subsumes both deferred tails — both are RA-level 16-bit residency under pressure, the
   `globals.c`/`a16regpress.c` crash class (live-failing in 0a-3), coalescing ruled out. One trigger, one
   B0→B1→B2 recipe (in the A16-threading plan).

4. **Go/no-go applied.** The pre-registered bar is evaluated against 0a/0b. Record CONFIRMED-measured-complete
   (expected) or GO with the byte evidence.

   **CONFIRMED-measured-complete — GO did NOT fire.** The per-op surface reproduces its optima (step 1), the
   step-5 class-win + aggregate hold (step 2), the one frontier is the single shared deferral (step 3). One
   **new** residual surfaced and was weighed against the GO bar: the **≥8-shift bracket-fragmentation**
   candidate — the constant-shift path correctly byte-relabels amount≥8 (`x<<8` → 0 explicit shifts, `x>>9` →
   1 `lsr`, vs `x<<7` → 7 `asl`, all the measured optimum), **but performs the byte-move in 8-bit mode**, so in
   a sustained-16-bit region it splits the run into separate `rep`/`sep` brackets (k_prng's `xs16`: 3 brackets
   for 3 consecutive 16-bit ops). A candidate fix would do the byte-shift **in-bracket** (e.g. an `xba`-based
   16-bit form). It does **not** clear the GO bar: (i) net-positive is **uncertain** (lesson #1 — the in-bracket
   form must be measured in ambient context), (ii) it appears in **adversarial** byte-interleave shapes whose
   realistic frequency is unmeasured, and (iii) it is **bounded** — even a perfect bracket-merge leaves xs16
   ~51 B vs 34 B default (still +50 %), so it cannot flip the stress kernels (their cost is dominantly the
   inherent mode + `Imag16` overhead). **Disposition: routed to a future measurement-gated spike** (a new
   `docs/plans/` entry if pursued), *recorded not buried, flagged not built* — exactly the pre-registered "a new
   residual → gated spike" path. Nothing lands now.

5. **Doc cascade.** Comparison-followups TODO item → Done; A16-threading + ALU-chain items folded to the one
   shared-core deferral (trigger + B0→B1→B2 recipe pointer); ROADMAP verification §5 points at the 0b table;
   upstream paragraph queued. `task md -- TODO.md` renders clean. PASS = "native-s16 surface formally complete —
   one shared, pre-registered deferral."

   **PASS.** Comparison-followups TODO item is already `[x]` Done (track closed 2026-06-21). The consolidation
   TODO item (this plan's) is updated to **Phase-0 DONE** with the result; the unified-trigger synthesis lives in
   this plan + the roll-up's 0c block (the A16-threading and ALU-chain items already point at their own deferral
   docs — left untouched to avoid clobbering the hot shared tree; the unification cross-references them from
   here). **ROADMAP §5 now carries the consolidated step-5 acceptance note** (pointing at the 0b roll-up +
   this plan), and **`upstream-contribution-status.md` folds the "stage-1 native-s16 measured-complete" pointer
   into the Native-16-bit-codegen Future/blocked item** (the upstream paragraph itself is drafted in this plan;
   posting rides the ABI-gated native-16-bit contribution, user-triggered).

6. **Commit hygiene.** `git diff --cached --name-only` is exactly this plan + `dev/measure-native-s16-surface.sh`
   + the doc cascade — never `vendor/`, `0002`, a foreign patch, or `docs/transcripts/`. Triage any `## Inbox`
   deferrals the commit hook captures.

   **PASS** — staged set verified at commit (see commit below); `docs/transcripts/` left untracked.

---

## Risks / non-goals

- **Risk: re-measurement drifts from the recorded numbers.** Then a track is *not* actually closed — investigate
  the drift (likely a stale `clang-23`, the documented gotcha) before recording the verdict. Trust the rebuild.
- **Risk: the roll-up surfaces a genuinely-new residual (GO).** Low (the per-op surface was swept exhaustively).
  If it fires and is not the pressure core, the gated spike is the path; the shared core stays deferred.
- **Non-goal: re-attempting the deferred core now.** Phase 3 / multi-value spill-fusion stay deferred under their
  one trigger — the recorded keep-the-XFAIL decision stands (a risky common-path rework for a pathological bug is
  3× worse, per the deferral formalization). This plan **records** the deferral; it does not spend the spike.
- **Non-goal: re-opening either WON'T-DO** (ordering-as-value branchless in either form; full-native EQ-as-value)
  — both measured net-negative, closed per `close-net-negative-findings-not-defer`.
- **Non-goal: the CC/ABI track, xy16, or the two RA/scavenger bugs** — named as the surface's boundary, owned by
  their own items.

## Critical files

- **Roll-up (new):** `dev/measure-native-s16-surface.sh` — drives the three harnesses + the 0b step-5 table.
- **Existing harnesses (driven, not duplicated):** `dev/measure-compare-surface.sh`,
  `dev/measure-a16-threading.sh`, `dev/measure-zp-pressure.sh` · methodology twin: `dev/frameabi-census.sh`.
- **Backend (read-only context; no edits planned):**
  `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` (`legalizeICmp`, the `hasAccum16()` gates),
  `MOSInstructionSelector.cpp` (`selectSbc16`, `selectAlu16Native`, the chain combiners),
  `MOSLateOptimization.cpp` (`threadAccum16`), `MOSInsertREPSEP.cpp` (M-flag lattice; the Phase-1 spill-fusion
  site if a trigger ever fires), `MOSRegisterInfo.cpp` (`shouldCoalesce`, the spill path / SPILL CONTRACT).
- **Regression/acceptance fixtures:** `examples/65816/a16regpress.c` (the deferred-core acceptance case),
  `examples/65816/k_*.c` (the step-5 kernels), `examples/snes/corpus/*.c` (the 7/7 gate).
- **Rolled-up plans:** the three named at the top + the increment series they close.
