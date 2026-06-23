# llvm-mos-65816 — project guide

Project-specific guide; **extends the shared `~/SRC/CLAUDE.md`** (generic conventions: plan-first, TODO
format, commit-at-checkpoints, only-commit-your-work, markdown rules). It is **auto-loaded every session**,
so it is the standing preface for every handoff: each piece of work = this guide (general) **+** a per-task
`docs/plans/YYYY-MM-DD-<topic>.md` supplement. **Build/test commands, gotchas, the differential gate
details, measurement methodology, and backend navigation live in
[`docs/agent-handoff.md`](docs/agent-handoff.md)** — read it before doing codegen work. Keep both current.

## What this project is

A from-source fork of **llvm-mos** adding native **16-bit-accumulator** codegen for the **WDC 65816** — the
opt-in target feature **`+mos-a16`** — plus a SNES platform to exercise it. GitHub issue **#321** (ROADMAP
step 5 / milestone **M2**). Orientation: `docs/ROADMAP.md` (M0→M1→M2), **`TODO.md`** (the live backlog; the
M2 section is the curated state of all #321 follow-ups), `docs/INVESTIGATION.md`. The 65816 runs in native
mode (crt0 does `XCE`); under `+mos-a16` the accumulator is 16-bit (`M=0`, entered/left via `rep`/`sep`).

## Source of truth & the `vendor/` model — read before editing

- The compiler source is **`vendor/llvm-mos/`** — the full LLVM/clang tree, **gitignored and edited in
  place.** You change C++ there and rebuild (`dev/run.sh toolchain`).
- The **tracked** artifacts are **`patches/llvm-mos/*.patch`** (`0002-321-accum16.patch` = all #321
  codegen). After editing `vendor/`, regenerate with **`dev/regen-patch.sh`**.
- **`vendor/` is shared** with concurrent agents/humans. **Only commit your own files.** Never stage
  `vendor/` (gitignored), a patch you didn't author, or `docs/transcripts/`. If you find another worker's
  in-progress `vendor/` edits, leave them — rebuild on top, don't revert.

## The bar

Correctness = the **differential**: host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean. Any disagreement or crash is a real defect, not a
glitch. (Exact commands + the micro-test pattern: `docs/agent-handoff.md`.)

## Three governing lessons (hard-won)

1. **Measure, don't assume.** Predicted codegen is often wrong here — build the real shape, diff the bytes,
   read the disasm; verify a rebuild actually took (the stale-`clang-23` gotcha). Measure in realistic
   16-bit-ambient context, not isolated leaf functions.
2. **A native 16-bit op is NOT automatically smaller.** It routes operands through the zero-page `Imag16`
   pair + a `rep`/`sep` bracket, which *loses* to a tight 8-bit `cpx;cmp`/byte path when an operand is
   register-resident (`$a:$x`, the first arg) or the value is consumed as bytes. The win depends on
   **operand residency** and **schedule** → **gate** a native form to fire only where it wins, and make the
   gate **conservative**: a misclassification must only ever *miss a win*, never *cause a regression*.
3. **Modest gains are worth doing.** On a compiler a few-byte win is amplified across every program built
   with the toolchain, so "high-effort / modest-gain" is a *scheduling* input, not a veto. But only
   *genuine* gains — a *blanket* change that regresses common shapes to win a sub-case is wrong; gate it.

## Commit discipline (project specifics; generic rules in `~/SRC/CLAUDE.md`)

- **Stage only your files**, explicitly; then verify `git diff --cached --name-only` is exactly your set —
  never `vendor/`, a foreign patch, or `docs/transcripts/`. When regenerating `0002`, sanity-check it
  didn't absorb another patch's hunks: `grep -c <foreign-symbol> patches/llvm-mos/0002-*.patch`.
- **Investigations go on throwaway worktrees, not `main`.** Measurements / spikes / probes (e.g. the
  ZP-pressure scan, `dev/measure-zp-pressure.sh`) run on a `throwaway/<slug>` branch in its own worktree off
  `main` HEAD — this repo's `main` working copy is a **hot shared tree** (concurrent agents leave `vendor/`,
  `0002`, `TODO.md` dirty mid-edit), so a worktree gives a clean checkout + clean commits with no surgical
  staging. The worktree has no `build/`: env-override `CLANG`/`OBJDUMP` to this checkout's
  `build/llvm-mos-install/bin/...` rather than rebuilding (host-side scripts only — for the Dockerized
  `dev/run.sh`, `cp -al` the prebuilt `build/` subdirs into the worktree instead; see
  [`docs/howto-feature-worktree.md`](docs/howto-feature-worktree.md)). **Keep** → merge the durable artifacts (script,
  recorded verdict) back; **dead-end** → `dev/worktree-teardown.sh throwaway/<slug> --yes` (raw
  `git worktree remove` is guard-blocked; the wrapper handles `throwaway/<slug>` too — disposable, so no
  retain-until-upstream gate, but `--yes` is still required). (Generic rule + rationale:
  `~/SRC/CLAUDE.md` "Worktree-based feature workflow".)
- **Commit hooks fire automatically:** `regen-md-history` snapshots edited plans into `docs/plans/.history/`;
  `audit-plan-deferrals` captures plan "Deferred"/unverified bullets into a `## Inbox` in `TODO.md` —
  **triage them** (delete a bullet already covered by a curated TODO item with a short
  `<!-- triaged YYYY-MM-DD: … -->` note; a fingerprint ledger keeps deleted items from returning), then
  re-commit `TODO.md`.
- End commit messages with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Push only when asked / coordinate.** `main` may carry other workers' commits not yet pushed (some route
  via fork PR branches deliberately); don't `git push origin main` without checking.
- **Upstream contributions are queued in [`docs/upstream-contribution-status.md`](docs/upstream-contribution-status.md)** —
  every PR / issue / design-note we draft for `llvm-mos`(-sdk), split ready-to-post vs future/blocked, each with its exact
  `gh` command. Posting is **user-triggered**. **Keep it current in the same commit** whenever you draft a new upstream
  artifact, push a PR branch, or post one (mirror the one-line pointer in TODO's *Upstream / Contribution* section).
