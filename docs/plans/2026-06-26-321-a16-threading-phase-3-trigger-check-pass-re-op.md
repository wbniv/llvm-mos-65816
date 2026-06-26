# #321 A16-threading Phase 3 — trigger-check pass (re-open or re-affirm the deferral)

**Date:** 2026-06-26 · **Status:** DONE — executed. **Mode:** measure-first, decision-gated.
**Scope of execution:** a throwaway worktree (host-only measurement + the existing differential harness).
**No `vendor/` change in this plan** — the compiler is only touched if a trigger fires (Phase B, separate
worktree).

> **OUTCOME (2026-06-26) — trigger (b) FIRED → ran the gated spike → CLOSED Phase 3 as measured net-negative.**
> The expected "DEFER stands" path did *not* hold: new heavy-16-bit math kernels (CORDIC/Mandelbrot/Hopalong)
> pushed 6 real fns to ~10/14 `Imag16` pairs (`cordic16_atan2` at the full 14/14), firing trigger (b);
> trigger (a) stayed clean. At the user's direction (B0-first, then B1-as-measurement) we built and measured
> the spike: **B0** (`shouldCoalesce` Ac16 barrier) is byte-for-byte **inert**; **B1** (pre-RA `Ac16`
> residency, hidden flag `-mos-a16-prera-residency`) **fires heavily but yields zero peak-ZP-pressure relief
> and a +24 B regression** — the single accumulator caps the gain, now proven. Nothing landed (default build
> byte-identical). **Full record + reproduce + the spike `.diff`:**
> [`docs/investigations/2026-06-26-a16-phase3-prera-residency-spike.md`](../investigations/2026-06-26-a16-phase3-prera-residency-spike.md).
> The B2 stage below was therefore not reached (B1 NO-GO).

## Context — why this change

`Phase 3 — RA-level Ac16 residency` is the last open slice of the M2 "#321 A16-threading" work and is
**explicitly deferred behind a re-open trigger**. Its disposition, corrected framing, concrete trigger, and
the gated **B0→B1→B2** spike recipe are already recorded in
[`docs/plans/2026-06-20-321-a16-threading-phase-3-formalize-the-deferral-r.md`](../../SRC/llvm-mos-65816/docs/plans/2026-06-20-321-a16-threading-phase-3-formalize-the-deferral-r.md)
and the A16-threading plan. The reward is already banked (Phases 0/1/1.5 left ~1 non-adjacent reload; folds
already optimal); the only remaining motivator is **one hand-reduced XFAIL** (`pr15296.c`,
`a16-zp-pressure-overflow`), which the trigger deliberately excludes. Both regalloc crashes once lumped into
this core got **orthogonal targeted fixes** (patches `0009`, `0011`+`0012`) — so as of today there is no 2nd
independent realistic crash, and the last ZP-pressure baseline (2026-06-18) put the busiest real function at
**~5/14 pairs** — half the trigger.

This is therefore **not** "implement Phase 3." Phase 3 is high-risk/low-reward and is correctly parked. What's
missing is a **disciplined, dated evaluation** of whether either documented re-open trigger has fired now —
and the durable evidence to either re-affirm DEFER or, only if a trigger fires, hand off cleanly to the
already-recorded spike. This honors the project's "measure, don't assume" and "abort early" lessons: we
re-measure against realistic code before spending the high-risk spike.

**Outcome:** a go/no-go verdict backed by a fresh dated measurement, written back into the Watch item / plan,
and (if and only if a trigger fires) execution of the existing B0→B1→B2 recipe.

## The two re-open triggers (verbatim, from the formalized deferral)

- **(a)** the corpus / c-torture / **fuzzer** surfaces a *second independent* `regalloc-out-of-registers`
  (or `a16-zp-pressure-overflow`) from **realistic** (not hand-reduced) code, **or**
- **(b)** the ZP-pressure baseline (`dev/measure-zp-pressure.sh`) shows a **real** corpus function crossing
  **~10 of 14** `Imag16` pairs.

`pr15296.c` does **not** count for (a) — it is a hand-reduced c-torture repro. A fresh **csmith** program does
count (the differential harness already treats csmith output as the realistic-code source).

## Decision model (the gate)

```
Phase A (cheap, host-only, throwaway worktree)
  ├─ A2  ZP-pressure re-measure over an EXPANDED real-code set
  │        → trigger (b) fires iff any real fn ≥ ~10 pairs (≈20 distinct __rc bytes)
  └─ A3  crash-sweep (fuzz large-N + corpus + broader real code, asserts/-verify-machineinstrs)
           → trigger (a) fires iff a NEW realistic seed/program hits
             regalloc-out-of-registers OR a16-zp-pressure-overflow

  NEITHER fires → RE-AFFIRM DEFER: record dated evidence, update Watch, teardown. DONE.
  EITHER fires  → PROCEED to Phase B (the recorded B0→B1→B2 spike, new compiler worktree).
```

## Phase A — trigger-check (throwaway worktree, no compiler edit)

### A1. Worktree (non-compiler path — hardlink the prebuilt toolchain, no rebuild)

Per `~/SRC/CLAUDE.md` "investigations on throwaway worktrees" and
[`docs/howto-feature-worktree.md`](../../SRC/llvm-mos-65816/docs/howto-feature-worktree.md). Branch
`throwaway/a16-phase3-trigger-check`. Host-only measurement needs only `CLANG`/`OBJDUMP`; the Dockerized
`dev/run.sh fuzz`/`corpus` needs the prebuilt `build/` subdirs `cp -al`'d in.

- `git -C <main> worktree add -b throwaway/a16-phase3-trigger-check <main>-a16phase3 main`
- Hardlink: `build/llvm-mos-install`, `build/install` (SDK), `build/jgxcheck`, `vendor/bsnes-jg`, `dev/roms`
  (exact `cp -al` block in the howto's "non-compiler work" recipe).
- Sanity: `dev/run.sh corpus` → 7/7 confirms the hardlinked toolchain works end-to-end.

### A2. ZP-pressure re-measure — evaluate trigger (b)

Reuse **`dev/measure-zp-pressure.sh`** (host-only; `CLANG` env-overridable). It already scans kernels
(`examples/65816/k_*.c`), corpus (`examples/snes/corpus/*.c`), and the `a16*` micro-tests, printing
per-function `distinct_rc` + `~pairs` and a SUMMARY.

Two gaps to close so the run actually tests trigger (b):

1. **The script's built-in verdict line is keyed to the wrong threshold.** Its `TIGHT` cut is `>=24` bytes
   (~12 pairs) and `pool-exhausting` is `>28`; the **trigger is ~10/14 pairs ≈ 20 distinct `__rc` bytes**,
   which is *below* the existing 24-byte line. Add a third, explicit trigger line to the SUMMARY `awk`
   (`MOSRegisterInfo`-style: `printf "  Phase-3 trigger (b): max real fn = %d bytes (~%.0f pairs) => %s\n",
   rmax, rmax/2, (rmax>=20?"FIRE":"defer-stands")`), and surface the max-function name. This is the only
   durable code artifact this plan produces — keep it (merge back).
2. **Expand the real-code set** beyond the 12 in-repo functions, since the trigger is about *realistic* code
   pressure. Add the SDK's own C sources and any additional real example programs already in the tree as
   extra `record real …` groups (e.g. compile the platform C library / non-trivial `examples/**` programs
   under the same `+mos-a16 -Os` flags). Keep csmith *out* of A2 (its pressure is covered by A3's crash
   sweep, and A2 is about real code).

**Read the result:** trigger (b) FIRES iff any real-code function reports `distinct_rc ≥ ~20` (≈10 pairs).
Otherwise record `rmax` and move on.

### A3. Crash-sweep — evaluate trigger (a)

A "second independent realistic crash" = a **new** `regalloc-out-of-registers` or `a16-zp-pressure-overflow`
from realistic code, distinct from the already-known/already-fixed cases. Build/test commands and the
KNOWN_ISSUES classification are in
[`docs/agent-handoff.md`](../../SRC/llvm-mos-65816/docs/agent-handoff.md).

- **Large-N csmith fuzz** on both emulators: `dev/run.sh fuzz 500 1` (and a second offset seed band, e.g.
  `dev/run.sh fuzz 500 501`). Expect 0 mismatch / 0 unclassified crash. A new seed that hits
  `regalloc-out-of-registers` / `a16-zp-pressure-overflow` and is **not** an already-known XFAIL seed ⇒
  trigger (a) FIRES. (The known scavenger seeds are fixed by `0011`/`0012`; they must stay clean here.)
- **Corpus + kernels + suite** under `+mos-a16 -Os` with `-mllvm -verify-machineinstrs`:
  `dev/run.sh corpus` (7/7) and the `a16*.sh`/`k_*.sh` suite — confirms no realistic regression/crash.
- **Broader real code** (optional, strengthens "realistic"): compile the SDK C sources / additional
  in-tree real programs under `+mos-a16 -O1` and `-Os` with `-verify-machineinstrs`; watch for either crash
  signature.

**Read the result:** trigger (a) FIRES iff any **realistic, not-previously-known** input crashes with one of
the two signatures.

### A4. Decision gate

- **Neither trigger fires →** the deferral stands, now with **fresh dated evidence**. Go to "Outcome:
  re-affirm DEFER."
- **Either trigger fires →** capture the exact reproducer (seed/program + signature + `-debug-only=regalloc`
  trace), then go to Phase B.

## Phase B — the spike (ONLY if a trigger fired)

Do **not** re-design this — execute the **already-recorded B0→B1→B2 gated spike** verbatim from
[`docs/plans/2026-06-20-…-formalize-the-deferral-r.md`](../../SRC/llvm-mos-65816/docs/plans/2026-06-20-321-a16-threading-phase-3-formalize-the-deferral-r.md)
(§"Spike recipe to embed") and the A16-threading plan. Summary so this file is self-contained:

- **New worktree, compiler-editing path** `throwaway/a16-phase3-spike` (real-copy `vendor/llvm-mos` + warm
  `build/`; asserts build via `dev/asserts-build.sh` for `-debug-only=regalloc,coalescing`). Commit nothing
  to `vendor/` until B2 is green.
- **B0 — barrier inertness.** Add only the `MOSRegisterInfo::shouldCoalesce` 8-bit↔`Ac16` barrier
  (`MOSRegisterInfo.cpp:745–784`). GO iff `dev/measure-a16-threading.sh` is **byte-identical** to the
  Phase-1.5 baseline AND the `a16*.sh`/`k_*.sh` suite + `a16localx` + `corpus` + `fuzz 200+` are clean.
  (Any codegen diff ⇒ our coalescer model is wrong — STOP.)
- **B1 — residency clears the crash without un-threading.** Minimal `selectAlu16Native`
  (`MOSInstructionSelector.cpp:~2377–2523`) single-use-thread change behind a hidden `-mllvm` flag, on B0.
  GO iff `a16regpress.c` compiles clean at **both** `-O1` and `-Os`; no round-trip/byte regression; zero
  8-bit↔A16 joins under `-debug-only=coalescing`. (Crash persists ⇒ confirms the investigation's caveat —
  abandon, keep XFAIL.)
- **B2 — broad correctness + net-neutral-or-better.** `fuzz 200+` 0 mismatch/crash/error on both emulators;
  `corpus` 7/7; full suite; `-verify-machineinstrs` clean; **net `.text` neutral-or-better across the whole
  set** (a sub-case win that regresses common shapes = NO-GO, lesson #3). Only after B2: land in `vendor/`,
  `dev/regen-patch.sh`, flip `a16regpress.c`/`pr15296` XFAIL→positive gate, drop the relevant
  `KNOWN_ISSUES` entry.

## Outcome: re-affirm DEFER (the expected branch)

If neither trigger fired, the durable deliverables are:

1. **Keep** the `measure-zp-pressure.sh` trigger-line + expanded-corpus change (merge to `main`).
2. **Record dated evidence** in the **Watch** item of
   [`TODO.md`](../../SRC/llvm-mos-65816/TODO.md) and/or the formalized-deferral plan: a one-line
   `2026-06-26 trigger-check: (b) max real fn = N bytes (~M pairs) < 10/14; (a) fuzz 1000 + corpus clean,
   no new regalloc/zp-overflow → DEFER stands` so the deferral stays self-explaining and the next reviewer
   sees the freshest measurement, not the 2026-06-18 one.
3. **Teardown:** `dev/worktree-teardown.sh throwaway/a16-phase3-trigger-check --yes` (durable artifacts
   already merged; the build/vendor dupes are reclaimed).

This is a closed loop, not an open backlog item — the trigger is re-armed with current data.

## Files touched

- `dev/measure-zp-pressure.sh` — add the explicit ~10/14-pair trigger verdict line + expanded real-code
  groups (durable).
- `TODO.md` (Watch item) and/or the 2026-06-20 formalized-deferral plan — append the dated trigger-check
  verdict.
- **Only if a trigger fires:** `vendor/llvm-mos/.../MOSRegisterInfo.cpp`, `.../MOSInstructionSelector.cpp`,
  `patches/llvm-mos/0002-321-accum16.patch` (regen) — per the B0→B1→B2 recipe, on the separate spike
  worktree.

## Verification

The deliverable is a dated go/no-go verdict; the measurement output **is** the evidence. Record raw output
under each numbered step in this plan (per `~/SRC/CLAUDE.md` plan-verification format).

1. **Worktree sane.** `dev/run.sh corpus` in the worktree → `7/7`. PASS = 7/7.
2. **Trigger (b) evaluated.** `CLANG=<main>/build/llvm-mos-install/bin/mos-clang dev/measure-zp-pressure.sh`
   → SUMMARY shows the new `Phase-3 trigger (b)` line. PASS = line present and reads `defer-stands`
   (FIRE ⇒ go to Phase B). Paste the per-function max row + the SUMMARY.
3. **Trigger (a) evaluated.** `dev/run.sh fuzz 500 1` and `dev/run.sh fuzz 500 501` → 0 mismatch, 0
   unclassified crash; no **new** `regalloc-out-of-registers`/`a16-zp-pressure-overflow` seed. `dev/run.sh
   corpus` 7/7; `a16*.sh`/`k_*.sh` suite clean; `-verify-machineinstrs` clean. PASS = all clean (any new
   realistic crash ⇒ Phase B). Paste fuzz tallies + any XFAIL classification.
4. **Evidence recorded.** `grep -n "2026-06-26 trigger-check" TODO.md` (or the plan) resolves. PASS = the
   dated verdict line is present.
5. **Markdown preview.** `task md -- TODO.md` (and any edited plan) — visual check, no rendering breakage.
6. **Commit hygiene.** Stage only your files; `git diff --cached --name-only` is exactly the
   `measure-zp-pressure.sh` + doc edits — never `vendor/`, a foreign `0002`, or `docs/transcripts/`. Triage
   any `## Inbox` deferrals the commit hook captures.

## Out of scope / non-goals

- **No compiler change unless a trigger fires.** Phase A is measurement only; Phase B is conditional.
- **The other two XFAILs** (`scavenger-p-not-gpr` fixed by `0011`/`0012`; `a16-zp-pressure-overflow` /
  `pr15296.c`) keep their own TODO bullets — `pr15296.c` is hand-reduced and is *not* a trigger by itself.
- **Not re-deriving the spike.** If a trigger fires, Phase B runs the recorded B0→B1→B2 recipe verbatim; we
  do not redesign the residency mechanism here.
