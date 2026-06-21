# Plan — #321 native-s16 surface consolidation: knock out the close-out

## Context — why this change

The native-s16 surface consolidation (`docs/plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md`)
is a **measure-and-close** (the #321 analogue of the #320 zero-bank closure): nothing is built; the deliverable
is a durable surface map proving the `+mos-a16` per-op codegen is at its measured optimum, with the one open
frontier named, gated, and risk-weighed. **Phase 0 already RAN (2026-06-22) and is recorded as all-PASS /
CONFIRMED-measured-complete.** Its three substantive artifacts are committed:

- `866d530` — the roll-up `dev/measure-native-s16-surface.sh` + the measured-complete verdict.
- `a584a78` — the doc cascade (ROADMAP §5 acceptance note + `upstream-contribution-status.md` fold).
- `95d65df` — the plan itself.

So the measurement, the script, the ROADMAP/upstream cascade are **done**. What is *not* done is the **TODO.md
finalization** the plan explicitly deferred ("the A16-threading and ALU-chain items… left untouched to avoid
clobbering the hot shared tree"). Two concrete gaps remain:

1. The consolidation TODO item (`TODO.md:122`) is still `[ ]`, and its trailing "**Remaining** low-risk doc
   touches: ROADMAP §5 pointer + the user-triggered upstream paragraph" is **stale** — both landed in `a584a78`.
2. The plan's headline value-add — *collapse three open native-s16 deferrals into one shared core* — isn't
   reflected in the live backlog: A16-threading Phase 3 (`TODO.md:230`), ALU-chain >14-live (`TODO.md:249`), and
   the `globals.c` `-Os` RA crash (`TODO.md:189`) still read as three separate "DEFERRED" tails.

This change finishes the close-out: promote the item to Done, reconcile the stale line, and unify the three
deferrals in the backlog. **Doc/backlog only — no compiler codegen, no `vendor/` edits, nothing built** (the
GO contingency did not fire; the one new candidate — ≥8-shift bracket fragmentation — was routed to a future
gated spike, not this item).

## Work to do (TODO.md only)

1. **Promote the consolidation item → Done.** Remove the `[ ]` block at `TODO.md:122` and add a tight
   `- 2026-06-22 — [321-native-s16-surface-consolidation]` entry at the top of the Done section (reverse
   chronological, ~1–2 lines per the TODO done-format rule). It records: native-s16 surface **measured-complete**
   via `dev/measure-native-s16-surface.sh`; compares CLOSED + threading/ALU-chain optima reproduce (roundtrips=0,
   0/13 pool-exhaust); the **honest a16-vs-default = MIXED** result (sustained-16-bit class wins — `chain −63%`,
   `multivalue −65%`, `k_isort −39%`, aggregate **−22%/−220 B**, corpus 7/7 — while 8/16-interleave stress
   kernels regress by-design, confirming why a16 is opt-in/per-op-gated); the **one shared deferred core** (=
   A16-threading Phase 3 ≡ ALU >14-live ≡ `globals.c` `-Os` crash, one trigger, one B0→B1→B2 recipe); the
   ≥8-shift bracket-frag candidate routed to a future spike (didn't meet the GO bar); doc cascade landed
   (`a584a78`). Link the plan.

2. **Unify the deferred core across the three still-open items.** Append one consistent clause to each of
   `TODO.md:189` (`globals.c` RA), `:230` (A16-threading Phase 3), `:249` (ALU-chain multi-value) — e.g.
   "**↔ Shared core:** RA-level 16-bit-value residency under register pressure — the *same* deferral as
   [A16-threading Phase 3 / ALU >14-live / `globals.c` `-Os` crash]; **one** re-open trigger (a 2nd independent
   *realistic* `regalloc-out-of-registers`/`a16-zp-pressure-overflow`, **or** a real fn crossing ~10/14 `Imag16`
   pairs) → **one** gated B0→B1→B2 spike; see the native-s16 surface close-out." This delivers the plan's
   "collapse three loose ends into one shared deferral" in the live backlog while preserving each item's history
   (no deletion/merge — the items keep their own rich provenance, they just cross-reference the one core).

3. **Triage the hook Inbox.** The commit fires `audit-plan-deferrals`; the plan's "Risks / non-goals" +
   "Disposition (GO)" bullets may be captured. Triage each into a `<!-- triaged 2026-06-22: … -->` note (they're
   recorded non-goals / a not-fired contingency, not open work) so the fingerprint ledger closes them.

## Files

- **edit:** `TODO.md` — promote the consolidation item to Done (move + shorten); unify the three deferred-core
  items; triage any captured Inbox bullets.
- No other files. ROADMAP §5 + `upstream-contribution-status.md` already carry the close-out (`a584a78`, plus a
  later user/linter touch to upstream-status); the plan + roll-up script are committed and stay as-is.

## Verification

1. **No measurement drift (the close-out's own acceptance bar).** Re-run the host-only roll-up
   `dev/measure-native-s16-surface.sh` on `main`'s installed toolchain and confirm the recorded headline states
   reproduce — compares native except register-resident EQ-as-value; A16-threading roundtrips=0; ZP 0/13
   pool-exhaust (max ~5/14); the a16-vs-default step-5 table (aggregate −22%); `dev/run.sh corpus` → 7/7. PASS =
   the recorded verdict still holds (no stale-`clang-23` drift). (Read-only measurement; deferred to execution.)
2. **Backlog reads as one collapsed surface.** After the edit: the consolidation item is in Done; the three
   deferred items each name the single shared core + the one trigger + the one recipe; no orphaned "Remaining
   doc touches" / stale "ROADMAP §5 pointer" text remains. `grep -nE 'shared core|one trigger|B0→B1→B2' TODO.md`
   shows the three items consistently cross-referenced.
3. **Renders + commit hygiene.** `task md -- TODO.md` renders clean. `git diff --cached --name-only` is exactly
   `TODO.md` — never `vendor/`, `0002`, a foreign patch, or `docs/transcripts/`. Inbox bullets triaged.

## Out of scope (explicit non-goals — per the plan's own boundaries)

- Building anything: A16-threading Phase 3 / multi-value spill-fusion stay **deferred** under their one trigger
  (a risky common-path rework for a pathological bug is 3× worse — the recorded keep-the-XFAIL decision stands).
- The ≥8-shift bracket-fragmentation candidate — routed to a *future* measurement-gated spike (a new `docs/plans/`
  entry if pursued); it doesn't meet the GO bar, so it's noted, not opened here.
- Re-opening either WON'T-DO (ordering-as-value branchless in either form; full-native EQ-as-value materialize).
- The CC/ABI track, xy16, and the two RA/scavenger *bugs* as bugs — owned by their own items; this close-out only
  unifies how the shared *deferred core* is described.
- The upstream paragraph posting — user-triggered (already drafted in-plan + folded into upstream-status).
