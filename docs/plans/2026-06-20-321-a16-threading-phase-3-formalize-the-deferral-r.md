# #321 A16-threading Phase 3 — formalize the deferral + record the spike recipe

**Date:** 2026-06-20 · **Status:** PLAN (docs-only) · **Scope:** `TODO.md` + the A16-threading plan doc.
**No `vendor/` change, no `0002` regen, no toolchain rebuild.**

## Context — why this change

The M2 "#321 A16-threading" item's last remaining slice is **Phase 3 — RA-level `Ac16` residency**, the
ROADMAP-step-5 "biggest win." Re-examining it at M2 wrap-up surfaced a **documented inconsistency** plus a
**stale, vague trigger** that this plan fixes — without touching the compiler.

Two facts, both already established in-repo, are in tension:

1. The A16-threading plan ([`docs/plans/2026-06-17-321-a16-threading.md`](../../SRC/llvm-mos-65816/docs/plans/2026-06-17-321-a16-threading.md))
   names Phase 3 as a **`shouldCoalesce` barrier** (reject 8-bit↔`Ac16` coalescing) plus selector relaxation
   — framed as *the* fix.
2. The regalloc-pressure investigation
   ([`docs/investigations/65816-a16-regalloc-pressure-failure.md`](../../SRC/llvm-mos-65816/docs/investigations/65816-a16-regalloc-pressure-failure.md),
   asserts root-cause `50a59b5`) proved **coalescing is RULED OUT** as the `a16regpress.c` crash cause —
   zero 8-bit↔`A16`/`Ac16` joins in the trace. The crash is many single-instruction **`Ac16` transits**
   (weight `INF`, unspillable) competing for the one accumulator while 8-bit loop machinery squats on `$a`
   and X/Y are taken. So the named barrier **does not fix the crash**; only the high-risk pre-RA
   `Ac16`-residency rework could.

Net: the reward is **already banked** (Phases 1/1.5 left ~1 non-adjacent reload; folds already optimal), the
only remaining gain is fixing one **pathological** `-Os`/`-O1` crash on slack code, and the risk is **high
and on the common path** (reopens the 1d coalescer crash / un-threads the −31/−36% wins). This is the exact
high-risk/low-reward profile governing **lesson #3** warns against. The recorded **DECISION 2026-06-18 —
keep the XFAIL** stands; what's missing is (a) a corrected framing of *what* Phase 3 actually is, (b) a
**concrete re-open trigger** in place of "reevaluate at M2 wrap-up," and (c) the **gated spike recipe**
captured so a future attempt is disciplined, not improvised.

**Outcome:** the deferral is durable and self-explaining — anyone reading TODO/Watch sees why Phase 3 is
parked, the precise condition that re-opens it, and the exact B0→B1→B2 procedure to run when it does.

## What Phase 3 actually is (corrected framing — record this)

- **The mechanism that could fix the crash** is **pre-RA `Ac16` residency**, at instruction selection in
  `selectAlu16Native` (`vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp`, ~2377–2523): when
  an operand is the single-use SSA result of a prior native s16 op, thread the producer's `Ac16` vreg
  directly into the consumer and skip the `STAImag16`/`LDAImag16` round-trip — collapsing 2N single-
  instruction `INF` transit vregs into one **spillable** multi-instruction `Ac16` range. Fewer unspillable
  transits → the A/X/Y deadlock is no longer forced. (Not a TableGen pattern — these are multi-instruction
  custom emissions with carry/overflow defs and a single-use dataflow judgment. Not a pre-RA RAUW pass —
  Phase 1 explicitly rejected that shape as the 1d-entanglement risk.)
- **The `shouldCoalesce` barrier is a SAFETY COMPANION, not the fix.** Once an `Ac16` value lives across
  ops pre-RA, the coalescer's window widens and the 1d invariant (no 8-bit `LDImm` coalescing into A16's
  low alias) must be *enforced* rather than holding emergently. Add to
  `MOSRegisterInfo::shouldCoalesce` (`vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp:745–784`, no
  `Ac16` barrier today) a rule returning `false` for any join merging `Anyi1`/`Anyi8`/`GPR` into
  `Ac16`/`A16`, keeping the `A16 = B:A` aliasing intact. Because no such coalesce happens today, **adding
  the barrier must be a measured no-op** — that inertness is the first gate.

## The edits (all docs)

### 1. `docs/plans/2026-06-17-321-a16-threading.md` — record disposition, trigger, recipe

- In the **Status** header and the **Remaining — (3)** paragraph, correct the "Phase 3 = `shouldCoalesce`
  barrier" framing to the two-part truth above: *the fix is pre-RA `Ac16` residency; the barrier is a
  safety companion that does not itself fix the regalloc crash (coalescing ruled out — see the
  investigation).*
- Replace verification step **5** ("Phase 3 (if attempted) — `a16localx` clean + `fuzz 200+` clean") with
  the full **gated spike recipe** below (it supersedes the one-line placeholder).
- Cross-link the investigation's "coalescing ruled out" conclusion explicitly.

**Spike recipe to embed (the future-execution procedure — run only when a trigger fires):**

Run on a **throwaway worktree** `throwaway/a16-phase3-spike` (project convention: investigations never on
`main`'s hot shared tree). Env-override `CLANG`/`OBJDUMP` to the main checkout's
`build/llvm-mos-install/bin/...`; asserts build via `dev/asserts-build.sh` for
`-debug-only=regalloc,coalescing`. **Product = a go/no-go decision; commit nothing to `vendor/` until B2 is
green.**

- **B0 — barrier inertness.** Add only the `shouldCoalesce` Ac16 barrier. **GO** iff
  `dev/measure-a16-threading.sh` is **byte-identical** to the Phase-1.5 baseline AND the `a16*.sh`/`k_*.sh`
  suite + `a16localx` + `corpus` + `fuzz 200+` are clean. **NO-GO** if *any* codegen differs (our model of
  the coalescer is wrong — stop and re-investigate).
- **B1 — residency clears the crash without un-threading.** Minimal `selectAlu16Native` single-use-thread
  change behind a hidden `-mllvm` flag, on top of B0. **GO** iff `examples/65816/a16regpress.c` compiles
  clean at **both** `-O1` and `-Os`; `measure-a16-threading.sh` shows **no** round-trip/byte regression on
  chains+kernels; `a16localx`/`a16local` verify-clean; `-debug-only=coalescing` shows **zero** 8-bit↔A16
  joins. **NO-GO** if the crash persists (confirms the investigation's caveat — abandon, keep XFAIL), any
  win regresses, or the 1d guard trips.
- **B2 — broad correctness + net-neutral-or-better.** `fuzz 200+` 0 mismatch/crash/error on both emulators;
  `corpus` 7/7; full suite; `-verify-machineinstrs` clean over examples + ≥200 fuzz; **net `.text` bytes
  neutral-or-better across the whole set** (a sub-case win that regresses common shapes = NO-GO, lesson #3).
  Only after B2: land in `vendor/`, `dev/regen-patch.sh`, flip `a16regpress.c` XFAIL→positive gate, drop
  the `KNOWN_ISSUES["regalloc-out-of-registers"]` entry.

### 2. `TODO.md` — M2 A16-threading bullet (lines ~128–141)

In the **Remaining — (3) … DEFERRED** sentence, (a) correct "via a `shouldCoalesce` barrier rejecting
8-bit↔`Ac16` coalescing (the `$a16 = LDImm` 1d crash)" to note the barrier is a **safety companion** and the
actual lever is **pre-RA `Ac16` residency** (coalescing ruled out as the crash cause), and (b) point to the
spike recipe + the concrete trigger now recorded in the plan doc and Watch.

### 3. `TODO.md` — Watch item (lines ~322–328): replace the vague trigger

Replace *"Revisit when M2 is closed out, or sooner if the Phase-3 `Ac16`-residency work becomes
independently motivated"* with a **concrete re-open trigger**:

> Re-open Phase 3 **only when** either **(a)** the corpus / c-torture / fuzzer surfaces a *second
> independent* `regalloc-out-of-registers` (or `a16-zp-pressure-overflow`) from **realistic** (not hand-
> reduced) code, or **(b)** the ZP-pressure baseline (`dev/measure-zp-pressure.sh`) shows a real corpus
> function crossing **~10 of 14** `Imag16` pairs. If a trigger fires, run the gated B0→B1→B2 spike
> (recipe in the A16-threading plan). Until then: **keep the XFAIL** (`examples/65816/a16regpress.c` is the
> ready acceptance case).

Keep the existing root-cause cross-link.

## Verification (docs-only — no build)

This change touches only markdown; the "build the real shape, diff the bytes" gate does not apply. Verify
documentation consistency instead:

1. **Trigger is concrete, not vague.** `grep -n "reevaluate at M2 wrap-up\|when M2 is closed out" TODO.md`
   — confirm the vague phrasings are gone from the Watch item (the M2-wrap-up *reevaluation* concept may
   remain only where it now points at the concrete trigger). PASS = no bare "revisit when M2 is closed out".
2. **Corrected framing landed.** `grep -n "safety companion\|coalescing ruled out\|pre-RA .*residency"
   TODO.md docs/plans/2026-06-17-321-a16-threading.md` — confirm both files now state the barrier is a
   companion and residency is the lever. PASS = matches in both files.
3. **Spike recipe present.** `grep -n "B0\|B1\|B2\|throwaway/a16-phase3-spike" docs/plans/2026-06-17-321-a16-threading.md`
   — confirm the B0→B1→B2 recipe replaced the old one-line step 5. PASS = recipe present.
4. **Cross-links resolve.** Confirm the investigation link
   (`docs/investigations/65816-a16-regalloc-pressure-failure.md`) and the `a16regpress.c` path exist:
   `ls docs/investigations/65816-a16-regalloc-pressure-failure.md examples/65816/a16regpress.c`. PASS =
   both exist.
5. **Markdown preview.** `task md -- TODO.md` and `task md -- docs/plans/2026-06-17-321-a16-threading.md`
   (per `~/SRC/CLAUDE.md` `md` workflow) — visual check, no rendering breakage.
6. **Commit hygiene.** Stage only the two edited files; `git diff --cached --name-only` is exactly
   `TODO.md` + `docs/plans/2026-06-17-321-a16-threading.md` — never `vendor/`, `0002`, or
   `docs/transcripts/`. Triage any `## Inbox` deferrals the commit hook captures.

## Out of scope / non-goals

- **No compiler change.** This plan deliberately does **not** attempt the residency rework — the user chose
  to formalize the deferral and bank the recipe, not to spend the spike now.
- **The other two XFALs** (`scavenger-p-not-gpr`, `a16-zp-pressure-overflow`) keep their own TODO bullets;
  this plan only touches the A16-threading / `globals.c`-RA pair.
