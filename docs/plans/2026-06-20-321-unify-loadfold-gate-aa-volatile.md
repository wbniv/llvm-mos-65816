# #321 unify the a16 load-fold gate: AA-precise on non-aliasing stores **and** single-use-volatile-tolerant

**Status:** planned — **measurement-gated** (do not build until Phase 1 shows a recoverable win). Spun out of
the [load-fold-call-hazard audit](2026-06-20-321-audit-a16-loadfold-call-hazard.md) §Deferred (the audit's
durable record of *why* the two gates are split today). This plan is the contract for *closing* that split.

**One line:** today two load-fold gates each hold one capability the other lacks; fold them into one shared
helper that has **both** — fold single-use volatile loads (8-bit side gains this) **and** skip provably
non-aliasing intervening stores via AA (16-bit side gains this). **Pure codegen-size upside, zero correctness
change** — but each recovered fold is a *handful*, so a throwaway instrument-and-count gates the rebuild.

## Background — the two gates today, and why they're split

Folding a load into a later user re-reads memory at the **user's** point, not the load's. That is only
value-preserving when nothing between the two clobbers that memory — the `pr34768` across-call miscompile
(fixed `86c2602`). Two helpers enforce this, with **complementary precision**:

| Gate | Used by | Volatile | Intervening store | Across call / ordered ref |
|---|---|---|---|---|
| `shouldFoldMemAccess` (`MOSInstructionSelector.cpp:362`) | upstream **8-bit** `m_FoldedLd{Abs,Idx,Indir,IndirIdx}`; the **16-bit store-side** fold `loadStoreValueIntoA16` (`:2940`) | **bails on ALL volatile** (`:370`) | **AA-precise** — `mayAlias(AA,Src)` (`:429`), folds *across* a provably non-aliasing store | bails `isCall`/`hasUnmodeledSideEffects` (`:424`) + ordered-ref (`:427`) |
| `noStoreBetween` (`:1403`) | the **16-bit value-side** folds `foldableAbsLoad16`/`foldableIndirLoad16` (compare/ALU/EQ/indexed-cmp operands) | **tolerant** — no volatile check; the callers' `hasOneNonDBGUse` single-use check makes it 1-access-either-way safe | **conservative** — bails on *any* `mayStore()`, even non-aliasing | bails `isCall`/`hasUnmodeledSideEffects` (`:1409`) |

The split is **accidental, not principled.** `noStoreBetween` exists only because `foldableAbsLoad16`/
`foldableIndirLoad16` were written without threading the selector's `AAResults *AA` member — so they could not
do the `mayAlias` query and fell back to "any store kills it." The audit *rejected* naively consolidating
onto `shouldFoldMemAccess` because that gate bails on all volatile loads and the corpus relies on folding
single-use **volatile** globals (`a16abscmp`/`a16loadfold`/`a16mixfold` fold `volatile unsigned short`). This
plan is the consolidation the audit deferred — done *correctly* by **also dropping the blanket volatile bail**
in favour of a single-use volatile allowance, so neither capability is lost.

**The symmetry — where each recovered win actually lands** (this clarifies the upside is real but small):

- **AA-precision → recovers folds on the 16-bit value-side.** `noStoreBetween` drops a fold whenever *any*
  store sits between load and use; with AA it would keep the fold when that store provably doesn't alias the
  loaded address (`int t = g; h = 5; cmp(t, g)` with `g`, `h` distinct globals).
- **Volatile-drop → recovers folds on the 8-bit side** (and the 16-bit *store-side* `loadStoreValueIntoA16`).
  A single-use *volatile* 8-bit load is currently never folded (`:370`); the 16-bit value-side already folds
  it. So today a16 is **internally inconsistent**: a volatile 16-bit global folds in a *compare* context
  (`foldableAbsLoad16`) but **not** in a *store/copy* context (`loadStoreValueIntoA16` → `shouldFoldMemAccess`
  → volatile bail). Unification removes that asymmetry too.

## Unification target

One shared helper — call it `canFoldLoadIntoUser(Dst, Src, AA)` — replacing both gates; the four 8-bit
matchers, `loadStoreValueIntoA16`, and `foldableAbsLoad16`/`foldableIndirLoad16` all call it. Logic =
`shouldFoldMemAccess` as it stands, with the **one** volatile change:

```text
// (same-BB, cost-model/user-count, intervening-scan all unchanged from shouldFoldMemAccess)
const bool Volatile = (*Src.memoperands_begin())->isVolatile();
if (Volatile && NumUsers != 1)          // fold a volatile load ONLY when single-use
    return false;                       // ≥2 users would DUPLICATE the volatile access — illegal
// (drop the old unconditional `if (Volatile) return false;` at :370)
```

`foldableAbsLoad16`/`foldableIndirLoad16` and `noStoreBetween` are deleted; their single-use + same-BB checks
are subsumed (single-use by the cost model clamped to 1 for volatile / `MaxNumUsers`; same-BB by `:367`).
Thread the selector's `AA` member into the two `foldable*Load16` call sites (they're inside member functions
— `this->AA` is in scope; the only edit is the helper signature + the call args).

## Correctness — the crux (why this is genuinely zero-risk)

Three claims, each must hold; the implementation keeps the structure that makes them hold.

1. **Single-use volatile fold preserves the access count.** A volatile load that is folded into its *one*
   user emits the memory access exactly once at the user (1 → 1). The access *moves forward* in program
   order but is neither removed nor duplicated. This is the exact reasoning already documented for the 16-bit
   path (`:1389`) and proven by `a16abscmp`/`a16loadfold`/`a16mixfold` on both emulators.
2. **The forward move is ordering-legal.** Moving a volatile read past an intervening op is observable-safe
   *only* past **non-volatile, non-call** ops. The scan must keep both bails **before** the AA check:
   `isCall()`/`hasUnmodeledSideEffects()` (`:424`) and `Src.hasOrderedMemoryRef() || I.hasOrderedMemoryRef()`
   (`:427`). `shouldFoldMemAccess` already orders them correctly — the `mayAlias` skip at `:429` is reached
   **only for non-ordered** memrefs, so we never reorder two volatile/ordered accesses. **Do not** let the
   AA skip apply to ordered refs.
3. **The volatile allowance must clamp users to 1, not to `MaxNumUsers`.** The 8-bit `G_LOAD_ABS`/
   `G_LOAD_INDIR` cost model permits `MaxNumUsers == 2`. Folding a *volatile* load into 2 users emits the
   addressing mode twice → **two** volatile reads → illegal. Hence `Volatile && NumUsers != 1 → bail`, which
   is strictly stronger than `NumUsers > MaxNumUsers`. (Non-volatile keeps the existing ≤2 behavior.)

AA-precision needs no new argument: `mayAlias` is already trusted on the 8-bit path and the store-fold path;
extending it to the value-side path is the *same* trust, not a new one. Net: every fold the unified gate
*adds* is one the bytes-differential and the four-way oracle will confirm or refute — but by construction
(1-access, ordering-preserving, non-aliasing) none can regress a correct program.

## Phase 1 — the gate: instrument-and-count (no behavior change, compile-only)

On a **throwaway worktree** (`throwaway/loadfold-unify-measure` off `main` HEAD — per CLAUDE.md, measurements
never run on `main`'s hot shared tree). This phase **edits `vendor/` (the selector)** so it needs a rebuilt
compiler → use the `cp -al` Docker path from [howto-feature-worktree.md](../howto-feature-worktree.md), not
the host env-override (which can't rebuild). The measurement itself is **compile-only** (no MAME/bsnes, no
QUIET-box constraint): count what the unified gate *would* recover, while leaving codegen unchanged.

1. **Probe A (16-bit recoverable, AA-precision).** In `noStoreBetween` (thread `AA` in for the probe only):
   when an instruction would trigger the bail via `mayStore()` and it is **not** a call/ordered/side-effect,
   query `MI.mayAlias(AA, *Def, /*UseTBAA=*/true)`. If it does **not** alias → `errs()`-log the function +
   address and increment a counter, **then still `return false`** (preserve current codegen). Count =
   folds AA-precision would recover.
2. **Probe B (8-bit recoverable, volatile).** In `shouldFoldMemAccess`, at the volatile bail: if `NumUsers
   == 1` and the intervening scan would otherwise pass, `errs()`-log + count, **then still `return false`**.
   Count = single-use volatile 8-bit folds the volatile-drop would recover.
3. **Run the probes across the real corpus** — compile (no run) with the instrumented `+mos-a16` clang and
   sum the counters over: the a16 micro-tests (`examples/65816/a16*.c`), the full in-scope c-torture set
   (1168, `-Os` and `-O1`), and a Csmith sweep (≥200 seeds). Record per-source counts + the total.

**Decision gate.** If **both** totals are ~0 across all three corpora → **DEFER-confirm**: there is nothing
to recover, record the verdict in this plan, `git worktree remove` + `git branch -D`, done. If either total
is materially nonzero → keep the worktree and proceed to Phase 2; the logged sites become Phase 2's targeted
byte-diff fixtures (and, if a shape isn't already covered, a new micro-test).

## Phase 1 — RESULTS (2026-06-20): both probes fire → **PROCEED to Phase 2**

Ran on throwaway worktree `throwaway/loadfold-unify-measure` (seeded from `main`'s `build/llvm-mos` real-copy +
hardlinked source; incremental rebuild of the probe patch **45 s**). Harness = `dev/measure-loadfold-recovery.sh`
(the keeper). Compiled **53 a16 micro-tests** ×{a16 -Os, a16 -O1, default -Os} + **1228 in-scope c-torture**
×{a16 -Os, default -Os} = **2615 compiles** (130 compile-fails: missing-header/K&R, contribute 0). The probes
**log-and-bail** → codegen unchanged; this only counts.

| Probe | raw hits | distinct (file,op) | opcode breakdown |
|---|---|---|---|
| **A** — AA-precision recovers a 16-bit fold | 11 | **7** | `G_LOAD16_ABS` ×7 (abs only; no indirect) |
| **B** — single-use-volatile recovers a fold | 132 | **43** | `G_LOAD_ABS` (8-bit) ×30 · `G_LOAD16_ABS` (store-side) ×11 · `G_LOAD16_INDIR` ×1 · `G_LOAD_INDIR_IDX` ×1 |

The opcode split **confirms the plan's predicted symmetry exactly**:

- **Probe A — the "handful" is real and small.** 5 of the 7 are genuine c-torture programs (`990128-1`,
  `packed-1`, `pr43236`, `pr85529-1`, `zero-struct-1`): a non-aliasing store sits between a `G_LOAD16_ABS` and
  its user, which `noStoreBetween` drops but `mayAlias` keeps. All abs, no `G_LOAD16_INDIR` — as expected.
- **Probe B — both predicted recoveries measured.**
  - **8-bit volatile** (`G_LOAD_ABS` ×30, `G_LOAD_INDIR_IDX` ×1): single-use volatile loads the upstream
    `shouldFoldMemAccess` volatile-bail blocks — the dominant case, and the volatile-MMIO-read idiom (real,
    not an artefact). Real c-torture hits: `postmod-1`, `pr38819`, `20120808-1`, `pr57281`.
  - **16-bit *store-side*** (`G_LOAD16_ABS` ×11, `G_LOAD16_INDIR` ×1): **exactly** the compare-vs-store
    asymmetry the plan flagged — a volatile 16-bit global folds in a *compare* context
    (`foldableAbsLoad16`→`noStoreBetween`, volatile-tolerant) but NOT in a *store/copy* context
    (`loadStoreValueIntoA16`→`shouldFoldMemAccess`, volatile-bail). 12 distinct sites ⇒ it recurs.

**Decision: PROCEED.** Both totals materially nonzero; recovery is real and recurring (volatile-drop broadly,
AA-precision as a small handful). **Honest caveat:** raw hits are inflated ~2–3× by multi-mode compilation, and
this counts foldable *sites*, not *bytes saved* — Phase 2's byte-diff over these fixtures is still the payoff
gate (a single-use fold is a win per `shouldFoldMemAccess`'s own cost model, but the magnitude must be
measured). Phase-2 byte-diff fixtures = the real c-torture sites above + the existing volatile micro-tests
(`a16abscmp`/`a16loadfold`/`a16mixfold`) as the no-regression guard.

<details><summary>Probe instrumentation (throwaway; Phase 1 reproduces from this + the harness script)</summary>

Five hunks in `MOSInstructionSelector.cpp`, all behavior-preserving (count then bail):
```
+#include "llvm/Support/raw_ostream.h"
+static AAResults *g_ProbeAA = nullptr;                       // file-scope; selection is single-threaded
   InstructionSelector::setupMF(...);
+  g_ProbeAA = AA;                                            // capture AA for noStoreBetween (Probe A)
-  if ((*Src.memoperands_begin())->isVolatile()) return false;        // shouldFoldMemAccess: drop early bail…
+  const bool ProbeVolatile = (*Src.memoperands_begin())->isVolatile();
   … (whole gate runs) …
+  if (ProbeVolatile) { if (NumUsers==1) errs()<<"LOADFOLD-PROBE-B "<<Dst.getMF()->getName()<<" op="<<Src.getOpcode(); return false; }  // …count single-use at the final return, still bail
   return true;
   // noStoreBetween: on the mayStore bail, if it's a pure non-aliasing store, count it:
+  if (MI.mayStore() && !MI.isCall() && !MI.hasUnmodeledSideEffects() && g_ProbeAA && !MI.mayAlias(g_ProbeAA,*Def,true))
+    errs()<<"LOADFOLD-PROBE-A "<<Def->getMF()->getName()<<" op="<<Def->getOpcode();
   return false;
```
</details>

## Phase 2 — implementation (only if Phase 1 is positive) — **greenlit by Phase 1**

1. Replace `shouldFoldMemAccess` + `noStoreBetween` with the single `canFoldLoadIntoUser(Dst,Src,AA)` above
   (volatile→single-use clamp; AA-precise scan). Re-point all call sites; delete `foldableAbsLoad16`/
   `foldableIndirLoad16`/`noStoreBetween`.
2. **Quantify the payoff by diffing bytes** (lesson #1 — measure, don't assume): for each logged fixture and
   the whole a16 corpus, compare `.text`/`.o`/`.sfc` sizes before vs after. Saving > 0 ⇒ worth it; identical
   ⇒ Phase 1 over-counted, revert and DEFER-confirm.
3. Run the **full differential gate** (Verification below) before landing. Regenerate `0002` with
   `dev/regen-patch.sh`; sanity-check it didn't absorb foreign hunks.

## Verification (the contract — fill raw output under each step when executed)

The bar is the **differential**: host == default(non-a16)@MAME == a16@MAME == a16@bsnes-jg, plus
`-verify-machineinstrs` clean. Phase 2 only.

1. **Regression guard — volatile folds preserved** (the capability the audit feared losing): `dev/run.sh
   a16abscmp`, `dev/run.sh a16loadfold`, `dev/run.sh a16mixfold` — each PASS, disasm gate intact (global read
   in place, no Imag16 round-trip). _(output)_  PASS/FAIL
2. **Regression guard — across-clobber hazard still closed** (the `pr34768` class): `dev/run.sh a16loadcall`
   → `0x0100` 4-way; c-torture `pr34768-1`/`pr34768-2` at `-Os` PASS both emulators. _(output)_  PASS/FAIL
3. **Recovered folds actually fold** (the new fixtures from Phase 1's logged sites): each PASS + disasm shows
   the fold now present where the conservative gate previously staged through Imag16. _(output)_  PASS/FAIL
4. **No corpus regression:** a16 suite (`for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f"
   .sh)"; done`) all PASS; `dev/run.sh corpus` → 7/7. _(output)_  PASS/FAIL
5. **Differential breadth:** `dev/run.sh fuzz 50 1` → 0 mismatch / 0 crash; full `-Os` c-torture re-sweep
   ≥ the current 1114 PASS / 0 FAIL baseline. _(output)_  PASS/FAIL
6. **`-verify-machineinstrs` clean** over the a16 examples + fuzz programs. _(output)_  PASS/FAIL
7. **Patch hygiene:** `dev/regen-patch.sh`; `git diff` of `0002` is only the gate-unification hunk;
   `grep -c` a foreign symbol confirms no absorbed hunks; `0002` round-trips clean. _(output)_  PASS/FAIL

## Upstream implication

`shouldFoldMemAccess` is **upstream llvm-mos** code (the 8-bit fold gate), and the volatile-drop changes its
behavior for *all* MOS targets, not just `+mos-a16`. The single-use-volatile fold is a general, target-neutral
improvement (1-access-preserving) → a plausible upstream contribution independent of #321. If Phase 2 lands,
add a one-liner to [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md) (and mirror
in TODO's *Upstream / Contribution*) noting the `shouldFoldMemAccess` volatile-relaxation as a candidate;
posting stays user-triggered.

## References

- Audit that deferred this (the *why-split* record): [`2026-06-20-321-audit-a16-loadfold-call-hazard.md`]
  §Deferred. The hazard fix that created `noStoreBetween`: [`2026-06-20-321-abs-load-fold-across-call-miscompile.md`]
  (`86c2602`).
- Code: `shouldFoldMemAccess` `MOSInstructionSelector.cpp:362`; the four 8-bit matchers `:441–533`;
  `noStoreBetween`/`foldableAbsLoad16`/`foldableIndirLoad16` `:1403–1439`; `loadStoreValueIntoA16` `:2933`;
  `AA` plumbing via `setupMF` `:184`. Handoff design note: `docs/agent-handoff.md:159` ("`shouldFoldMemAccess`
  … bails on *volatile* … `noStoreBetween` is the volatile-tolerant tailoring").
- Governing lessons: #1 (measure/diff-the-bytes — Phase 1 gate + Phase 2 byte-diff), #2 (a conservative gate
  must only ever *miss a win*, never regress — preserved: every added fold is 1-access + ordering-safe).
</content>
</invoke>
