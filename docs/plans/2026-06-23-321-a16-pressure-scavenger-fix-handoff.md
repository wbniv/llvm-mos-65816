<!-- HISTORY: snapshots in docs/plans/.history/ (regen-md-history hook). -->

# HANDOFF — fix the `+mos-a16` register-pressure crashes (scavenger N/Z + regalloc-out-of-registers)

> **OUTCOME (2026-06-24) — CLEAN PARTIAL DONE. `regalloc-out-of-registers` FIXED (fork patch `0009`);
> `scavenger-p-not-gpr` + `a16-zp-pressure-overflow` remain XFAIL.** Execution record + verification:
> [`2026-06-24-321-a16-pressure-fix-implementation.md`](2026-06-24-321-a16-pressure-fix-implementation.md).
> The handoff's premise that "both crashes share one root cause; fixing the pressure resolves both" was only
> *half* right: a fresh asserts pinpoint showed `globals.c`/`a16regpress.c`'s deadlock is a single **A-pinned
> i8 byte index** (`i += 2` → `ADCImm`/`Ac`={A}) blocking the `Ac16` transit — fixed conservatively by
> `selectAddSub` lowering a small-const i8 add/sub to a relocatable `G_INC`/`G_DEC` chain under `hasAccum16()`
> (DEFAULT byte-identical; net −123 B/122 c-torture progs; corpus 7/7, a16 suite 57/0, fuzz 0-mismatch).
> SCAVNZ + pr15296 have **no i8 byte index** (pure native-s16 pressure, byte-identical pre/post `0009`), so
> they still need the deferred **Phase-3 `Ac16`/ZP-residency rework** (a 13-agent design workflow + the prior
> spike concur; maintainer-territory for any standalone scavenger patch). On `wt/321-a16-pressure`
> (`c53c417`+); land `0009` to `main`'s shared `vendor/`+patch stack is the coordinated follow-up.

**For:** a fresh agent on higher settings. **Date:** 2026-06-23. **Issue:** #321 / ROADMAP M2.
**Read first (this guide is the standing preface):** [`CLAUDE.md`](../../CLAUDE.md) (project) +
[`~/SRC/CLAUDE.md`](../../../CLAUDE.md) (generic) + [`docs/agent-handoff.md`](../agent-handoff.md)
(build/test commands, the differential gate, backend nav, the stale-`clang-23` gotcha). **This file is the
per-task supplement.**

## Mission (one line)

Make the two deferred `+mos-a16` **register-pressure** crashes compile cleanly **and** pass the differential
gate, by doing the **A16-threading Phase-3 `Ac16`-residency / pressure rework** — the deliberately-deferred
hard core. Both crashes share one root cause; fixing the pressure should resolve both.

## The two crashes (same root cause, two symptoms) — both currently XFAIL'd

| repro | symptom | XFAIL signature (tools/a16_fuzz.py KNOWN_ISSUES) |
|---|---|---|
| `examples/65816/a16scavnz.c` | scavenger N/Z crash → illegal `STImag8 $p` / `assertNZDeadAt` | `scavenger-p-not-gpr` |
| `examples/65816/a16regpress.c` | `error: ran out of registers during register allocation` | `regalloc-out-of-registers` |
| (c-torture `pr15296.c`) | link-time `R_MOS_ADDR8 out of range … .zp` | `a16-zp-pressure-overflow` |

Reproduce (release; the exact fuzzer command — **no `--config`**):
```
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs \
  -c examples/65816/a16scavnz.c -o /dev/null      # → "$p is not a GPR register"
  -c examples/65816/a16regpress.c -o /dev/null     # → "ran out of registers"
```

## ROOT CAUSE — do not re-derive; it is pinned

The 65816 has **one** physical 16-bit accumulator (`Ac16` = `A16`). Under `+mos-a16` at `-O1`/`-Os`, native
s16 values saturate it. Two independently-pinned findings:

1. **The regalloc crash (asserts-build pinpoint, 2026-06-18, in
   [`docs/investigations/65816-a16-regalloc-pressure-failure.md`](../investigations/65816-a16-regalloc-pressure-failure.md)):**
   the unspillable vregs are **`Ac16` *transits*** — single-instruction live ranges like
   `%122:ac16 = LDAbsIdx16 @B,%123` that *must* hold `$a16` for that instant. `CalcSpillWeights` makes
   single-instruction ranges effectively INF (unspillable); when several compete and `A16` is never freed →
   "ran out of registers." **Coalescing is RULED OUT** (`-debug-only=…coalescing` shows zero 8-bit↔`A16`
   joins), so the *named* Phase-3 candidate (reject 8-bit→`Ac16` coalescing — that fixes the unrelated 1d
   `LDImm` crash) is **not** this fix. The real lever: **reduce the number of competing `Ac16` transits**
   (schedule/lower so fewer load/store transits are simultaneously live), with the soft-stack `Ac16` spill
   path as fallback.

2. **The scavenger crash (asserts + diagnostic, 2026-06-23 spike, this turn — see
   [`docs/plans/2026-06-23-321-scavenger-nz-fix-spike.md`](2026-06-23-321-scavenger-nz-fix-spike.md)):**
   the illegal `STImag8 $p` is only a *symptom*. The scavenger spills `P` to preserve N/Z across a
   frame-index materialization; the soft P-spill is illegal across an unbalanced range. **When you remove
   that symptom (two attempts below), the scavenger then asks for an accumulator-class (`Ac`) scratch and
   finds none** — diagnostic: `Register: '' num=0 RC=Ac` (num 0 = `MOS::NoRegister`). i.e. the *same*
   `Ac16`/accumulator pressure exhaustion as crash 1. So fixing the pressure (a free accumulator is always
   reachable) is expected to dissolve the scavenger crash too.

**Verdict:** there is **no bounded scavenger-only patch.** The fix is the pressure rework. Fix home =
[A16-threading **Phase 3**](2026-06-17-321-a16-threading.md) §"Phase 3 — RA-level `Ac16` residency".

## RULED OUT — do NOT spend time re-trying these (already tested, with evidence)

- **`canSaveScavengerRegister(MOS::P)` N/Z gate** (refuse P when N/Z live). → illegal `STImag8 $p` goes away
  but the scavenger dead-ends on `report_fatal_error("Scavenger spill for register not yet implemented")`
  (`RC=Ac`, `NoRegister`). Symptom relocation, not a fix.
- **`LDCImm` rematerializable** (`MOSImmediateLoad` lacks `isReMaterializable`; `LDCImm`→`CLC`/`SEC` touches
  only C, so it *is* remat-safe and arguably a real latent improvement). → changes the crash signature, same
  `Ac` dead-end. Not a fix on its own. (If Phase-3 work wants it as a *companion* cleanup, it must be
  differential-tested — it changes codegen — and **must not** be applied to the base class, because the
  sibling `LDImm` = `LDA/LDX/LDY #imm` writes N/Z and is not remat-safe.)
- **Anti-coalesce barrier / reject 8-bit→`Ac16` coalescing.** Ruled out as the cause (finding 1) *and*
  carries two regression risks: (a) regressing A16-threading's wins, (b) reopening the 1d coalescer crash
  guarded by `examples/65816/a16localx.c`.

## What "done" requires (acceptance)

1. **Both repros compile clean** (`-verify-machineinstrs`): `a16scavnz.c` and `a16regpress.c` under
   `+mos-a16 -O1` and `-Os`. Asserts build does **not** abort (`assertNZDeadAt`, "ran out of registers", or
   "not yet implemented").
2. **Differential gate** (the bar — see `docs/agent-handoff.md`): host == default@MAME == `+mos-a16`@MAME ==
   `+mos-a16`@bsnes-jg, for the corpus + the a16 micro-suite + a fuzz sweep. Use `dev/run.sh fuzz 50 1`
   (then a larger sweep) — in particular the 8 scavenger seeds `169/173/196/268/271/272/306/420` and the
   regalloc/zp-overflow seeds must go **0-mismatch / 0-crash**.
3. **No regression:** `dev/run.sh corpus` 7/7; `a16localx.c` (1d coalescer-crash guard) and the
   A16-threading win micro-tests stay green; `-verify-machineinstrs` clean tree-wide.
4. **XPASS guard flips:** `dev/run.sh known-issues` — the `scavenger-p-not-gpr`, `regalloc-out-of-registers`,
   and `a16-zp-pressure-overflow` repros must now **XPASS** (compile clean). Then **de-XFAIL**: remove those
   three `KNOWN_ISSUES` entries in `tools/a16_fuzz.py`, and promote `a16scavnz.c` / `a16regpress.c` to
   positive gates (the comments in each repro + the `KNOWN_ISSUES` block say "REMOVE this entry when fixed").
5. **Land:** carry as a stacked fork patch (next number, currently `0009`; regen per the patch workflow in
   `CLAUDE.md`); update `docs/implementation-status.md` + `TODO.md`; if the fix is upstreamable, draft the
   PR and (user-triggered) reference/close the queued scavenger issue
   ([`docs/321-upstream-scavenger-nz-issue.md`](../321-upstream-scavenger-nz-issue.md), filed/queued as
   item 4 in [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md)).

## Where to work (the fix locus)

- **Pressure/spill:** `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp` (spill weights / scavenger),
  `MOSInstrInfo.cpp` (the `Ac16` spill lowering — `STAImag16`/`LDAImag16`, `STAbs16`/`STAIndir16`, the F3
  soft-stack path), the legalizer/selection that creates `Ac16` transits (`MOSLegalizerInfo.cpp`,
  `MOSInstructionSelector.cpp`), and possibly scheduling. The investigation doc names the mechanism; the
  *exact* culprit transit/vreg must be re-pinpointed on an **asserts build**.
- **Scavenger symptom (only if the pressure fix doesn't fully cover it):** `saveScavengerRegister` /
  `canSaveScavengerRegister` / `assertNZDeadAt` in `MOSRegisterInfo.cpp` (lines ~126–268 on the current
  pin). The two fix *directions* the issue lists (a real flag-preserving P save across an unbalanced range;
  or stop frame-spilling the `%N.subcarry` vregs) are the fallback if pressure alone leaves a residue.

## Method (mandatory)

- **Asserts build is REQUIRED.** The release verifier only catches the *symptom*; pinpointing the culprit
  coalesce/transit and the failing vreg needs `dev/run.sh asserts-build` (→ `build/llvm-mos-asserts-install`)
  + `-debug-only=reg-scavenging`, `-debug-only=regalloc`, `-debug-only=…coalescing`, and pre-PEI MIR
  (`llc -stop-before=prologepilog`). **Confirm the asserts build actually rebuilt** — its `clang-23` mtime
  must advance (the spike hit a *stale* asserts install whose mtime never moved; `dev/run.sh asserts-build`
  exited 0 but served old codegen — verify before trusting any trace).
- **Worktree (compiler-changing variant):** spin up a fresh `wt/<slug>` per
  [`docs/howto-feature-worktree.md`](../howto-feature-worktree.md) "Compiler-changing variant" — `cp -a`
  vendor + the **warm** `build/` (release *and* asserts trees) so rebuilds are fast incrementals. ~12 GB.
  After every `vendor/` edit, re-confirm `build/llvm-mos-install/bin/clang-23` mtime advanced.
- **Measure, don't assume** (governing lesson 1): build the real shape, read the MIR/disasm, diff bytes.
  A wrong blind change here is worse than the current XFAIL (governing lesson: gate conservatively; a
  misclassification must only ever miss a win, never regress).
- **Debugging cap:** ≤3 hypotheses per sub-problem, then summarize + reassess (this is hard, iterative RA
  work — expect several measured cycles).

## Disposable spike worktree from the prior investigation

`wt/scavenger-nz` (`/home/will/SRC/llvm-mos-65816-scavenger-nz`) holds the scavenger spike, **reverted to
pristine** (no fix landed). It is a dead-end *for the scavenger-only approach* but its warm release+asserts
build is reusable. Either reuse it (revert any edits first) or tear it down
(`dev/worktree-teardown.sh scavenger-nz --yes`) and start fresh. Durable artifacts are already on `main`
(the spike plan + the strengthened issue).

## Pointers (read these)

- [`docs/investigations/65816-a16-regalloc-pressure-failure.md`](../investigations/65816-a16-regalloc-pressure-failure.md) — **the** root-cause doc (asserts pinpoint, fix-requirements, risks, cost/benefit).
- [`docs/plans/2026-06-17-321-a16-threading.md`](2026-06-17-321-a16-threading.md) §"Phase 3" — the fix home.
- [`docs/plans/2026-06-23-321-scavenger-nz-fix-spike.md`](2026-06-23-321-scavenger-nz-fix-spike.md) — the scavenger spike (3 attempts, the `RC=Ac/NoRegister` diagnostic).
- [`docs/investigations/65816-a16-scavenger-nz-liveness.md`](../investigations/65816-a16-scavenger-nz-liveness.md) — the scavenger N/Z analysis.
- [`docs/321-upstream-scavenger-nz-issue.md`](../321-upstream-scavenger-nz-issue.md) — the upstream issue draft (filed/queued; both tested dead-ends documented).
- `tools/a16_fuzz.py` `KNOWN_ISSUES` — the three signatures to flip + de-XFAIL on success.

## Honest expectation

This is the genuine M2 hard core, deferred on purpose. It is RA/spill-weight/scheduling surgery on the
single-accumulator model, with real regression risk. Budget for multiple asserts-build measurement cycles.
Success = both repros compile + differential-clean + the XPASS guard flips + no A16-threading regression.
A clean partial (e.g. only `a16regpress.c` fixed) is still progress — land it gated and report what remains.
