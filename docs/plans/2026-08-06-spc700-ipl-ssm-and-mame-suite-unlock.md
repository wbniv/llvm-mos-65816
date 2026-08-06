# SPC700 IPL — SSM provisioning + full MAME-leg suite unlock

**Date:** 2026-08-06 · **Status:** IN PROGRESS · **Item:** TODO `[T2]` · **Owner:** this session

**Supersedes the open question in** [`docs/plans/2026-08-03-spc700-ipl-ssm-provisioning.md`](2026-08-03-spc700-ipl-ssm-provisioning.md)
(that plan's Option A/B/C decision). **User decision, 2026-08-06: Option B — SSM, retrievable.**
That plan's full design (parameter path, script contracts, CLI surface, cost, verification steps
1–12) is adopted here verbatim and not re-derived; this doc covers only what's new: executing it
for real, and the follow-on the working MAME leg unlocks.

**Visible surface:** none — infra scripts, an AWS parameter, and CI-adjacent test-suite output. No
mockups.

## Context

Confirmed this session: `dev/roms/s_smp/spc700.rom` is present on this box (user-supplied 2026-08-03
via a disassembly reassembled to bytes — `sha1 97e352553e94242ae823547cd853eecda55c20f0`, exact
match) and **the MAME leg is genuinely running**, not skipping — verified live by re-running
`dev/run.sh cartsize-canary`: every cartridge-size config so far (hirom4, exhirom6, exhirom8,
lorom512k_slow, …) passes structural + disasm + **MAME** + bsnes-jg + entropy-independence.

Two things follow, both directed by the user this session:

1. **Provision it durably (Option B).** The ROM currently exists in exactly one place on one
   machine, reconstructed by a ~90-line scratchpad Python script that isn't in the repo. A fresh
   clone or a second box has nothing. Put it in AWS SSM as the source of truth and make it
   fetchable, per the existing plan's design.
2. **Unlock the full MAME-backed differential suite.** With a working IPL, `dev/run.sh corpus`,
   `dev/run.sh corpus-a16`, and `dev/run.sh torture` stop being bsnes-jg-only and become genuine
   two-emulator differentials — the "5-way" bar (host, default/a16/xy16 × MAME + bsnes-jg) the
   project's `~/CLAUDE.md` bar describes, previously only partially available here.

## Part 1 — SSM provisioning (adopts the 2026-08-03 design)

- **Parameter:** `/llvm-mos-65816/snes/spc700_ipl_b64`, `SecureString`, **us-west-2**.
- **Scripts:** `dev/fetch-spc700.sh` (idempotent, cached, sha1-gated, `--check`), `dev/seed-spc700.sh`
  (one-time put, refuses to overwrite without `--force`, refuses bad input — wrong size, wrong
  sha1 — before ever calling `put-parameter`).
- **Wiring:** `dev/_emu.sh`'s `require_bios` self-heals — calls fetch once before declaring the
  BIOS missing, so a clean clone with working credentials never sees `SKIP MAME` at all.
- **Taskfile:** `task spc700` / `task spc700:check` / `task spc700:seed`.
- **Doc:** `docs/howto-spc700-ipl.md` — where it lives, how to re-seed after total loss, why not
  GitHub secrets (write-only, can't be read back — the deposit-box/backup distinction from the
  2026-08-03 plan).
- **Credentials:** per-project IAM user `65816-terraform` (account `353144603271`, this box's only
  existing profile — `invest-terraform` — belongs to a different project and is not used for the
  application secret; `~/CLAUDE.md`'s per-project-credentials rule). Minted via the `/iam-bootstrap`
  skill (self-narrowing: starts broad enough to create the SSM parameter + a scoped policy, then
  narrows itself to exactly `ssm:GetParameter`/`ssm:PutParameter` on `/llvm-mos-65816/*` +
  `kms:Decrypt` on the `aws/ssm` key, via its own `terraform apply` — no lasting broad grant).

## Part 2 — full suite unlock

Once the IPL is durably fetchable (not just present as a one-off local file), re-run with MAME
enabled and record deltas against the bsnes-jg-only baseline:

- `dev/run.sh corpus` and `dev/run.sh corpus-a16` — the full differential slice sets.
- `dev/run.sh torture` (c-torture).
- A Csmith slice if time allows (`dev/run.sh fuzz --gen csmith`).
- The cartsize-canary matrix (already running as of this doc; full results recorded below once
  complete).

**Non-goal:** bulk-rewriting the ~100+ historical "MAME leg SKIP/pending (no SPC700 IPL)" annotations
sprinkled across already-`[x]` Done demo entries in `TODO.md`. Those are point-in-time history of
what ran when a demo was built, not a backlog — rewriting them retroactively would be noise, not
signal. A specific demo's MAME leg can be re-run for real verification on request; this pass scopes
to the suite-level commands above, which is what "the entire suite" means in this repo's own
vocabulary (`docs/plans/2026-08-03-spc700-ipl-ssm-provisioning.md`'s own payoff criteria, steps
9–11).

## Verification

1. `dev/fetch-spc700.sh --help` / `dev/seed-spc700.sh --help` exit 0, print usage, no AWS call.
2. `shellcheck` clean on both new scripts.
3. Negative controls: a 63-byte file and a wrong-sha1 64-byte file both refuse to seed, no
   `put-parameter` issued.
4. Real seed: `dev/seed-spc700.sh dev/roms/s_smp/spc700.rom` (the file already verified correct
   this session) → `aws ssm get-parameter --with-decryption` round-trips to the known sha1.
5. Cold fetch: delete the local file, `dev/fetch-spc700.sh` → restored, sha1 PASS.
6. Cache hit: re-run, no-op (no `GetParameter` call).
7. Corrupt-parameter negative control: temporarily seed a truncated value, fetch refuses to write
   and leaves any existing good file alone; restore the real value after.
8. `dev/run.sh cartsize-canary` — full matrix, MAME leg PASS on every config (in progress; will
   record the complete table here).
9. `dev/run.sh corpus` / `corpus-a16` / `torture` — MAME leg PASS where previously SKIP, results
   match the recorded bsnes-jg CRCs (no new divergence).
10. `dev/run.sh xcheck-suite` unchanged (proves no regression in the bsnes-jg-only path).
