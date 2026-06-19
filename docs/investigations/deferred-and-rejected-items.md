# Deferred & rejected items — #320 / #321 (M0 → M2)

*Every codegen path, optimization, or decision that was **not** carried to completion — measured and
rejected, reverted, gated behind a trigger, parked, or kept as a known XFAIL. This is the negative-space
companion to the [plan index](plan-index.md): the plan index lists what landed; this lists what was
deliberately **not** built, and why, so a future worker doesn't re-explore a settled dead-end. Every row
cites the disposition record (plan, `TODO.md`, or investigation note).*

All three of the project's governing lessons drive these dispositions: **(1)** measure, don't assume —
predicted codegen is often wrong here, so each rejection below is a *measured* regression (a spike in a
throwaway worktree, or a corpus trigger check), not a guess; **(2)** a native 16-bit op is not
automatically smaller — it loses to a tight 8-bit path when operands are register-resident, so a blanket
form that regresses common shapes is wrong; **(3)** modest gains are worth doing, but only *genuine* ones
— gate, don't blanket. So most "rejected" rows are a measured regression caught by lesson (2)'s bar, and
most "deferred" rows are a real win gated behind a trigger that hasn't fired.

## Legend — decision types

| Decision | Meaning |
|---|---|
| **DEFERRED** | A genuine win, **gated behind a named trigger** that has not yet fired. |
| **XFAIL** | A real defect, **expected-fail and tracked**, with a deliberate decision not to fix it now. |
| **PARKED** | Shelved for an external/environmental reason; revisit only if a need arises. |
| **REJECTED** | Built/spiked, **measured a regression**, will not implement. Tree left unchanged. |
| **WON'T-DO** | Not built — the triggering code pattern is **absent from the corpus**, so no payoff to chase. |
| **REVERTED** | Prototyped, crashed/regressed, **reverted** to keep the tree green (may be superseded later). |

The table leads with the **DEFERRED** items (live work, gated on a trigger), then the still-open
XFAIL / PARKED items, then the settled **REJECTED / WON'T-DO / REVERTED** dead-ends.

## The table

| Item | Decision | Why | Revisit trigger | Source |
|---|---|---|---|---|
| **A16-threading Phase 3 — RA-level `Ac16` residency** (keep the value in the accumulator across ops at allocation time) | DEFERRED | Gain capped by the **single** hardware accumulator, and it reintroduces the **coalescer-crash risk**. Phase 1/1.5 already captured the realizable win coalescer-free (true non-adjacent remainder was 1/300). | Becomes independently motivated, or needed to fix `globals.c` RA failure. | [A16-threading](../plans/2026-06-17-321-a16-threading.md) |
| **16-bit ALU multi-value register pressure — Phase 1 spill-fusion** | DEFERRED (with evidence) | The premise "only one 16-bit slot" is **misleading** — there are ~14 `Imag16` pairs, not one; measurement shows the pressure item is mostly already solved. | A Phase-0 trigger scan finds real cross-value spill churn in the corpus. | [multi-value register pressure](../plans/2026-06-18-321-16bit-alu-multivalue-register-pressure.md) · [ZP-pressure measurement](../plans/2026-06-18-321-zp-pressure-measurement.md) |
| **CC frame — TCD direct-page window** (sub-decision **a**: `PHD`/`TCD` remap DP onto the frame) | DEFERRED | Phased decision (2026-06-18): first-pass ABI **keeps the soft static stack** (c); defer the TCD window behind a measured trigger. | Zero-page pressure exceeds the threshold the baseline measurement established (14 usable pairs). | [CC frame decision](../plans/2026-06-18-321-cc-frame-phased-decision.md) |
| **CC — argument-passing + full hardware-stack frame ABI** | DEFERRED | The hard frame fork; gated on a product steer **and** post-xy16 measurement. Return convention (A/X) is the one CC piece already landed. | Credible implementation maturity + the product steer; tracked at M2 wrap-up. | [CC analysis](65816-calling-convention-decision.md) · [A/X return (landed)](../plans/2026-06-17-321-ax-return-convention.md) |
| **Variable / ≥8 constant shifts going native** | DEFERRED (left as-is) | The libcall / byte-relabel path is **already optimal** for variable and ≥8 shift amounts; native 1–7 shifts already shipped. | None expected. | [inc-dec accumulator §scope](../plans/2026-06-15-321-native-s16-inc-dec-accumulator.md) |
| **Soft-stack P3 — upstream issue: `reentrant` attr cannot force the soft stack** | DEFERRED (drafted) | Draft written; **posting is user-triggered** (upstream engagement), not auto-submitted. | User triggers the upstream post. | [soft-stack spill coverage §P3](../plans/2026-06-16-321-soft-stack-spill-coverage.md) |
| **xy16 — remaining REPSEP X-annotation gaps** (PHX/PLX/PHY/PLY in X16; transfers in mixed modes) | DEFERRED (watch) | Speculative — **no corpus/fuzz evidence yet**. The concrete instances that *did* surface (TAX/TAY/TXY/TYX, seed-31/157) were fixed; the rest are tracked as watch items. | Fuzz evidence of a real mismatch on one of these forms. | [REPSEP X-annotation §Out-of-scope](../plans/2026-06-18-repsep-x-annotation-for-x-governed-transfers-push.md) |
| **`+mos-a16` `$p`-spill compiler crash** (8 fuzz seeds: 169/173/196/268/271/272/306/420) | DEFERRED (open) | Pre-existing, separate from the xy16/REPSEP work; the 8 residual `fuzz 500` crashes. Out of scope of the seed-31 critical-edge fix. | Its own open item — a dedicated spill-path fix. | [critical-edge analysis](../plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md) · TODO Open |
| **`globals.c` `+mos-a16 -O1/-Os` register-allocation FAILURE on real code** | XFAIL | Isolated-asserts root-cause proved there is **no targeted fix** — only the general Phase-3 `Ac16`-residency rework, which is high-risk (regresses the common a16 path) and low-reward for a **pathological** case (real code has slack). | **M2 wrap-up**, or sooner if Phase-3 residency becomes independently motivated; `a16regpress.c` is the ready acceptance case. | [TODO §Watch](../../TODO.md) · [RA-pressure investigation](65816-a16-regalloc-pressure-failure.md) |
| **Mesen2 as a third emulator** | PARKED | Prebuilt crashes on Ubuntu 26.04 (glibc 2.43, `free(): invalid pointer`); headless `--testrunner` won't run Lua. MAME + bsnes-jg already give a two-emulator cross-check. | A third independent opinion is needed (would require a source build against 26.04). | [TODO §Parked](../../TODO.md) · [second-emulator plan](../plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md) |
| **Formal #320/#321 psABI document** | PARKED | Premature — llvm-mos is implementation-first (`@mysterymath` won't bless an ABI ahead of a high-quality implementation). | A credible implementation exists, or the maintainers ask. | [TODO §Parked](../../TODO.md) · [upstream design-note plan](../plans/2026-06-14-320-upstream-design-note.md) |
| **Full-native EQ-as-value materialize (Option A** — reuse-ops, carry→diamond**)** | REJECTED | **+14 B** on every shape; the existing select-diamond already fuses the compare into a `CmpBr` that branchless materialization forgoes. | None — settled. | [full-native materialize](../plans/2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md) |
| **EQ-as-value materialize (Option B** — branchless `rol`/`adc` tail**)** | REJECTED | **+16…+28 B** (worse than A): forgoes `CmpBr` compare-fusion, must form `X=LHS^RHS` + a standalone `lda #0; cmp X` for the carry. A hand-built `CmpSel*16` pseudo would pay the same two costs. | None — settled (both options measured). | [prove Option B](../plans/2026-06-18-prove-option-b-rol-tail-materialization-for-native.md) |
| **Blanket native EQ-as-value** (all operand shapes) | REJECTED → **gated** | Blanket form routes register/global operands through `Imag16` + `rep`/`sep` that the tight 8-bit `cpx;cmp` avoids (+4/+12 B in the spike). Shipped instead as **four gated wins** (v1 indirect, v3 both-global, `g==imm`, v2 computed). | n/a — superseded by the gated impls. | [EQ-as-value spike](../plans/2026-06-16-321-native-s16-eq-as-value-cmpsel.md) |
| **`x == 0` as a value, native** (task7 item 2) | REJECTED | Native `rep/sep` compare is **+5 B** vs the 8-bit byte-OR (`G_CMPZ`) path. | None. | [task7 §item 2](../plans/2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md) |
| **Indirect s16 load consumed only as bytes** (extend `AllUsesUnmerge` to `G_LOAD16_INDIR`) | REJECTED | Win is **schedule-dependent**: −6 B only when load is adjacent to its byte-compare; **+2 B regression** when 16-bit math is scheduled between (the common shape). Blanket gate can't tell them apart → fails the "not meaningfully worse elsewhere" bar. The real fix (native EQ-as-value) removes the `G_UNMERGE` entirely. | n/a — subsumed by the gated native EQ-as-value. | [indirect-s16-load-bytewise](../plans/2026-06-16-321-indirect-s16-load-bytewise.md) |
| **`inc abs` / `dec abs` 16-bit memory-RMW** (for global `g ± 1`) | REJECTED (reverted) | The 65816 has **no `inc long`**; `inc abs` is **DBR-relative** while this platform addresses all data via DBR-independent 24-bit long. It only *happens* to work via the low-8 KB WRAM mirror — a latent miscompile for any high global. Shipped `lda; inc a; sta` (3 instrs) instead. | None — hardware constraint. | [inc-dec memory-RMW](../plans/2026-06-15-321-native-s16-inc-dec-memory-rmw.md) |
| **Indir-dst copy fold** (`*p = gg`, `*q = *p` with a volatile dst-pointer load between value-load and store) | WON'T-DO | Corpus trigger check: **0/6 programs, 0 B** — no `sta (zp)` in 16-bit context, no `__IMAG16` round-trip pattern anywhere. The −13 B from natural 16-bit mode is already captured; a selector reorder isn't justified. | A real program exhibiting `volatile T *volatile p` 16-bit stores. | [indir-dst copy fold](../plans/2026-06-18-321-indir-dst-copy-fold.md) · [handoff](../plans/2026-06-18-321-indir-dst-copy-fold-handoff.md) |
| **Increment 1d — first GISel-native s16 prototype** (value transient in `A16`) | REVERTED | Crashed the register coalescer: an 8-bit `LDImm` coalesced into `A16` (whose sublo *is* the 8-bit `A`) → malformed `$a16 = LDImm`. **Superseded** by 1d-retry (value resident in `Imag16`, coalescer-safe). | n/a — replaced by 1d-retry. | [increment 1d](../plans/2026-06-14-321-increment-1d-gisel-native-s16.md) |

## Notes on items that *look* rejected but aren't

- **F3 — compare-result-as-value `SelectImm` crash** was XFAIL'd (8 fuzz seeds) in the Tier-1 corpus
  work, then **FIXED** (spill `Ac16` via 16-bit load/store; `fuzz 50/50`, 0 xfail). Not a standing
  rejection. [F3 fix](../plans/2026-06-16-321-fix-cmp-value-selectimm.md).
- **seed-31 critical-edge X16 liveness** was implemented → reverted (regressed seed-160) → **re-landed**
  after the X-governed transfers were annotated (`fuzz 500 → 492/500`). Ultimately DONE.
  [critical-edge](../plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md).
- The **1b/1c GISel combiner peephole** was retired (~1,400 lines deleted), but that was a *successful*
  refactor — the GISel-native path subsumes it — not a rejection.

## How this was compiled

Sources: plan **status headers** (grep `WON'T-DO|WON'T-IMPLEMENT|REVERTED|SKIP|DEFER|XFAIL`), the
`## Watch` and `## Parked` sections of [`TODO.md`](../../TODO.md), the triaged `## Inbox` deferral
ledger, and the in-plan "Deferred" / "Out of scope" sections. Update this table when a plan lands a new
WON'T-* / DEFER disposition, or when a deferred trigger fires and the item moves to the plan index.
