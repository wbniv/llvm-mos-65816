# #321 audit: every a16 load-fold site vs the "fold across a memory-clobbering call/store" hazard

**Scope:** a read-only audit (no codegen change expected) hardening the bug *class* found by the broad `-Os`
c-torture sweep and fixed in `86c2602` — a 16-bit load folded into a later ALU/compare operand **across a
call/store** that clobbers the loaded memory (gcc c-torture `pr34768-1/-2`; see
[fix plan](2026-06-20-321-abs-load-fold-across-call-miscompile.md)). Question: **does any *other* a16 fold
site share the latent flaw?**

**Target:** `vendor/llvm-mos/llvm/lib/Target/MOS/` — every selection/peephole path that folds a load (or memory
operand) into an instruction at a *later* program point than the load.

## The hazard (what to look for)

A fold is unsafe **only** when it moves a memory read from the load's point `P1` to a *later* user's point
`P2 > P1`, and something between `P1` and `P2` writes that memory (a call, or an aliasing store). Lowering a
single load/store node *in place* is never the hazard — the access stays at its original point. So the audit
targets only the **combine-a-load-into-a-later-user** patterns.

## Method

`grep` every load-fold construct across the MOS target and read each guard:
`getVRegDef`/`getOpcodeDef` → `G_LOAD*`, the `m_FoldedLd*` matchers, `shouldFoldMemAccess`, `cloneMemRefs`,
the post-RA `threadAccum16`/late peepholes, and the `CmpBr*` fusions. For each, determine whether an
intervening call/aliasing-store can sneak the read past a clobber.

## Findings (2026-06-20) — the two fixed helpers were the ONLY vulnerable sites

| Fold site | Guard against intervening clobber | Verdict |
|---|---|---|
| Upstream 8-bit `m_FoldedLdAbs`/`Idx`/`Indir`/`IndirIdx` (`MOSInstructionSelector.cpp:441–530`) | `shouldFoldMemAccess(Dst,Src,AA)` — bails on `isCall`/`hasUnmodeledSideEffects` + any `mayAlias` store (`:420–435`), same-BB + non-volatile | **safe** |
| `loadStoreValueIntoA16` store-value fold (`:2940–2943`) | `shouldFoldMemAccess(StoreMI,*Def,AA)` | **safe** |
| `threadAccum16` + post-RA late peepholes (`MOSLateOptimization.cpp:107,119,489`) | explicit `isCall()`/`mayStore()`/`modifiesRegister(A16)` bails | **safe** |
| `selectMem16Indir` / `selectMem16Abs` | lower a *single* G_LOAD16/G_STORE16 node in place — no cross-point move | **n/a — safe** |
| `CmpBrAbsAbs16` expansion (`MOSInstrInfo.cpp:396,1430`) | only *expands* an already-selected pseudo; fold decision is `selectBrCondImm`→`foldableAbsLoad16` (now guarded) | **safe** |
| `foldableAbsLoad16` / `foldableIndirLoad16` (compare/ALU/EQ/indexed-cmp operand folds) | **was single-use + same-BB only → the bug**; now `noStoreBetween` | **FIXED `86c2602`** |

## Why not consolidate the helpers onto `shouldFoldMemAccess` (the codebase standard)?

Considered and **rejected**. `shouldFoldMemAccess` bails on **all volatile loads** (`MOSInstructionSelector.cpp:369`),
but the #321 design deliberately folds *single-use volatile* operands (one access either way →
correctness-preserving), and the corpus/tests depend on it — `a16abscmp`, `a16loadfold`, `a16mixfold` fold
`volatile unsigned short` globals (verified). Switching would **regress** those folds and break their disasm
gates. `noStoreBetween` + the existing single-use check is the right tailoring: folds single-use volatile
loads **and** blocks the across-clobber hazard.

The two guards are therefore **complementary by design, not redundant**:
- `shouldFoldMemAccess` — AA-precise on aliasing (folds across provably-non-aliasing stores), but volatile-strict.
- `noStoreBetween` — volatile-tolerant, but conservatively bails on *any* intervening store/call.

## Deferred → RESOLVED 2026-06-20: AA-precision landed, volatile-drop re-deferred

The unification was specced, measured, and **split** by the byte-diff — see
[the unify plan §Phase 2 RESULTS](2026-06-20-321-unify-loadfold-gate-aa-volatile.md):

- **AA-precision LANDED.** `noStoreBetween` → **`noClobberBetween`** + a `mayAlias(AA, *Def)` check (an
  *ordered* store still hard-bails, so a volatile load never reorders across a volatile store). Recovers the
  handful of folds the old "any store" rule dropped — **−26 B** over the a16 corpus, **0 regressions**,
  differential-clean on both emulators.
- **volatile-drop CLOSED (net-negative, not pursued).** Dropping `shouldFoldMemAccess`'s volatile bail is
  *correct* but measured **net +17 B / 19 regressions** — folding a single-use volatile load *consumed as
  bytes* loses to imag8 (`a16abscmp` +43, `a16cmp` +37). A residency/schedule-gated version could keep the
  modest wins, but they're entangled with the losses and the gate is high-effort — **recorded, not a backlog
  item.** Reverted.
- **The literal single-helper merge was rejected by measurement:** it inherits `shouldFoldMemAccess`'s
  ordered-ref scan bail and regresses `a16abscmp`'s `volatile g1 == g2` fold (which folds `g1` across `g2`'s
  intervening volatile load). The two gates stay complementary — `noClobberBetween` (volatile-tolerant +
  now AA-precise) and `shouldFoldMemAccess` (volatile-strict) — **not** merged.

## Conclusion

**The bug class is closed.** The one defect was already fixed in `86c2602`; the audit found no sibling and
produced **no code change**. This plan is the durable record.

## Verification

- Audit is read-only; the correctness evidence is the fix's own verification (pr34768 `-Os` PASS, `a16loadcall`
  0x0100, full `-Os` re-sweep `1114/0`, full bsnes-jg pass `1174/0`) — see
  [fix plan](2026-06-20-321-abs-load-fold-across-call-miscompile.md) and
  [sweep plan](2026-06-20-321-broad-c-torture-sweep.md).
- No `vendor/`/`0002` change → nothing to rebuild or round-trip.

## References

- Fix [`2026-06-20-321-abs-load-fold-across-call-miscompile.md`] (`86c2602`); sweep that found it
  [`2026-06-20-321-broad-c-torture-sweep.md`]. Code: `shouldFoldMemAccess`
  `MOSInstructionSelector.cpp:362`; `foldableAbsLoad16`/`foldableIndirLoad16`/`noStoreBetween` `:1403–1438`;
  `loadStoreValueIntoA16` `:2933`; `threadAccum16` `MOSLateOptimization.cpp:423`.
