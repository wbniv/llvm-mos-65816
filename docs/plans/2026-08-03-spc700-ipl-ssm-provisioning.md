# SPC700 IPL provisioning — make the MAME leg rebuildable from SSM

**Date:** 2026-08-03 · **Status:** SUPERSEDED IN PART — see *Update: the IPL is reproducible* · **Owner:** infra

> ## Update (same day): the IPL turned out to be reproducible from source
>
> The user supplied **eKid's commented SPC700 IPL disassembly** (public, widely circulated; original
> disassembly from SID-SPC by Alfatech/Triad). It assembles to the IPL **exactly**:
>
> ```
> size    = 64 bytes (expect 64)
> sha1    = 97e352553e94242ae823547cd853eecda55c20f0
> expect  = 97e352553e94242ae823547cd853eecda55c20f0
> VERDICT = MATCH
> ```
>
> The ROM is **installed** at `dev/roms/s_smp/spc700.rom` (confirmed still ignored by `.gitignore:17`),
> and the MAME leg is live again for the first time in this repo's recorded history.
>
> **This makes the SSM design below largely redundant.** A 64-byte artifact regenerable from a ~90-line
> assembler needs no secret store, no credentials, no IAM user, and no `65816-terraform` bootstrap —
> `~/CLAUDE.md`'s "everything must be reproducible from the repository" is satisfied *better* by a
> generator than by a parameter fetch. Steps 1–8 and the whole *Credentials* section are on hold.
>
> **The open question is policy, not engineering, and it is the user's call:** the generator emits
> bytes identical to Nintendo firmware, and this repo's standing rule (`.gitignore:17`, README) is that
> the IPL is *"Nintendo content, supplied out-of-band, never committed."* Committing the generator is
> arguably committing the ROM in source form. Until the user decides, the assembler lives **outside the
> repo** in the session scratchpad and only its 64-byte output is installed locally.
>
> - **Option A — commit the generator** (`tools/gen-spc700-ipl.py` + `dev/_emu.sh` self-heal). Fully
>   reproducible, zero infrastructure, works on any fresh clone and in CI. Requires deciding the
>   published-disassembly question is acceptable.
> - **Option B — keep it out, use SSM** as originally planned below. Preserves the never-committed rule
>   literally; costs an IAM user and a credential dependency.
> - **Option C — neither**; the ROM stays a manual per-machine step, as it has been.
>
> Everything below is the Option B design, retained intact and still valid if that is the choice.
**Related:** [Round 7 demo battery](2026-08-03-round7-defect-hunting-demos.md) (the nineteen demos
currently running bsnes-jg-only), [`docs/agent-handoff.md`](../agent-handoff.md) (gate mechanics)

## Context — what actually broke

`dev/roms/s_smp/spc700.rom` (the SPC700 IPL, 64 bytes, sha1
`97e352553e94242ae823547cd853eecda55c20f0`) is **absent on this box**, and there is no copy anywhere
under `~/`. The consequences are not cosmetic:

| Surface | State without the IPL |
|---|---|
| `dev/run.sh corpus-a16` — the 112-slice differential suite | **exits 2.** Not degraded — *zero* slices run |
| `dev/run.sh corpus` | same |
| 116 of 299 `dev/*.sh` gate scripts | MAME leg prints `SKIP`, gate continues on bsnes-jg alone |
| Round 7 (nineteen demos) | no independent second emulator, no cross-slice regression coverage |

The only stored copy is the **GitHub Actions secret `SNES_SPC700_ROM_B64`** (`gh secret list` → set
2026‑06‑13), which `.github/workflows/smoke.yml` base64-decodes into place for its `smoke` / `xcheck`
/ `torture` / `fuzz-csmith` jobs. **GitHub Actions secrets are write-only** — the API will not read one
back — so CI can *use* the value but nothing can *retrieve* it.

That is the whole defect: a deposit box was used as a backup. Those are different jobs. The GitHub
secret is doing its job correctly; what is missing is a **retrievable** copy.

**This is not a new convention** — `~/CLAUDE.md` already says all secrets live in AWS SSM Parameter
Store as `SecureString`, and that the stack must be rebuildable from repo + a handful of secrets. The
IPL simply never got there. Size is not the obstacle: 64 bytes against a 4 KB Standard parameter.

**Searched and ruled out (2026‑08‑03):** the full SSM inventory of account `353144603271` — us‑east‑1
(18 parameters) and us‑west‑2 (40); all other regions hold zero. Nothing IPL-shaped under any name.
Secrets Manager and S3 were **not** searched (blocked by the permission classifier); if the file turns
up there, this plan's seeding step is simply skipped.

## Design

Three pieces, smallest thing that closes the loop:

1. **SSM is the source of truth.** `/llvm-mos-65816/snes/spc700_ipl_b64`, `SecureString`, **us‑west‑2**
   (where the project family's parameters already live — `indri-studio`, `parkingspace`, `wf-org`).
   Base64 of the 64 raw bytes.
2. **`dev/fetch-spc700.sh`** materializes `dev/roms/s_smp/spc700.rom` from that parameter — idempotent,
   cached, sha1-verified, and a no-op when the file is already correct.
3. **One wiring point.** `dev/_emu.sh` is the shared BIOS preflight behind all 116 MAME-carrying gate
   scripts. It gains a self-heal call so a missing IPL *fixes itself* instead of exiting 2.

### Why the fetch runs host-side

`dev/run.sh:409-410` runs everything in Docker with a single bind mount, `-v "$ROOT":/work`. The
container has no AWS CLI and no credentials, and mounting them in would be the wrong blast radius. So
the fetch runs on the **host**, before `docker run`, writing into `dev/roms/` — which is inside `$ROOT`
and therefore already visible at `/work/dev/roms` inside the container. No Dockerfile change.

### Integrity, both directions

Seed and fetch both assert **size == 64** and **sha1 == `97e35255…`** before writing anything. A
truncated parameter, a base64 mangled by a shell, or a wrong file handed to the seeder fails loudly
rather than producing a ROM that boots MAME into garbage and reads as a differential failure. The sha1
is the same constant `dev/_emu.sh:50` already prints in its error message — lifted to a shared
variable rather than duplicated.

### Credentials — the real dependency to fix

This repo has **no AWS credentials of its own**. The only profile on the box is `invest-terraform`
(account `353144603271`), which belongs to a different project. Using it here violates
`~/CLAUDE.md`'s per-project-credentials rule ("a leaked or rotated token then blast-radiuses exactly
one domain").

The scripts therefore take `SPC700_AWS_PROFILE` (default `65816-terraform`) and fail with an explicit
message naming the missing profile, rather than silently borrowing whatever is ambient. Minting that
IAM user is **step 5** below — until it exists, `SPC700_AWS_PROFILE=invest-terraform` is the documented
stopgap, and the failure message says so.

## Files

| File | Status | Purpose |
|---|---|---|
| `dev/fetch-spc700.sh` | new | Materialize the IPL from SSM. Idempotent, cached, sha1-gated. `--check` reports without fetching |
| `dev/seed-spc700.sh` | new | One-time: validate a supplied ROM and `put-parameter` it. Refuses to overwrite without `--force` |
| `dev/_emu.sh` | modified | Shared preflight self-heals: call the fetch once before declaring the BIOS missing |
| `Taskfile.yml` | modified | `task spc700` (fetch), `task spc700:check`, `task spc700:seed` |
| `docs/howto-spc700-ipl.md` | new | Where it lives, how to re-seed after a total loss, why not GitHub secrets |
| `.gitignore` | verify | `/dev/roms/` already ignored — assert, don't re-add |

**Not touched:** the 116 gate scripts. They keep their existing `SKIP` behaviour verbatim; the
self-heal happens one level below them in `dev/_emu.sh`, so nothing regresses if SSM is unreachable.

## CLI surface

The only visible surface is terminal output, so there is **no HTML mockup bundle** — the real output
states are specified here instead. Four states, all of which must be exercised in verification:

**Cache hit (the common case — must be silent and fast):**
```
$ dev/fetch-spc700.sh
    ok  SPC700 IPL present and verified (sha1 97e35255…, 64 B)
```

**Cold fetch:**
```
$ dev/fetch-spc700.sh
==> SPC700 IPL missing — fetching from SSM
    parameter: /llvm-mos-65816/snes/spc700_ipl_b64 (us-west-2, profile 65816-terraform)
    wrote dev/roms/s_smp/spc700.rom (64 B)
    PASS  sha1 97e352553e94242ae823547cd853eecda55c20f0
```

**No credentials — must name the fix, not just fail:**
```
$ dev/fetch-spc700.sh
==> SPC700 IPL missing — fetching from SSM
    FATAL: AWS profile '65816-terraform' not found in ~/.aws/credentials.
           This repo has no credentials of its own yet (see docs/plans/2026-08-03-spc700-ipl-ssm-provisioning.md step 5).
           Stopgap: SPC700_AWS_PROFILE=invest-terraform dev/fetch-spc700.sh
```

**Integrity failure — must refuse to write:**
```
    FATAL: fetched 41 B, expected 64 B — refusing to write a partial IPL.
           The SSM parameter is corrupt; re-seed with dev/seed-spc700.sh.
```

## Cost

| Item | Unit price | Monthly |
|---|---|---|
| SSM Standard parameter × 1 | $0.00 (Standard tier is free) | **$0.00** |
| `SecureString` KMS — `aws/ssm` default key | $0.00 (AWS-managed key) | **$0.00** |
| `GetParameter` API calls | $0.05 / 10 000 | **~$0.00** (cache hit means ~0 calls/day) |
| **Total** | | **$0.00/mo** |

Effectively free. The cache means a developer fetches once per machine, not once per gate run.

## Verification steps

1. `dev/fetch-spc700.sh --help` exits 0 and prints usage (no AWS call).
2. `dev/seed-spc700.sh --help` exits 0 and prints usage (no AWS call).
3. `shellcheck dev/fetch-spc700.sh dev/seed-spc700.sh` clean.
4. Negative control — seeding refuses bad input: feed a 63-byte file and a wrong-sha1 64-byte file;
   both must exit non-zero with no `put-parameter` issued.
5. Seed the real ROM (**needs the user's file**): `dev/seed-spc700.sh <path>`; confirm
   `aws ssm get-parameter --with-decryption` round-trips to sha1 `97e35255…`.
6. Cold fetch: `rm -f dev/roms/s_smp/spc700.rom && dev/fetch-spc700.sh` → file restored, sha1 PASS.
7. Cache hit: re-run; must be a no-op (no `GetParameter` call — verify with `--debug` or CloudTrail).
8. Negative control — corrupt parameter: temporarily seed a truncated value, confirm the fetch refuses
   to write and leaves any existing good file intact. Restore.
9. **The payoff:** `dev/run.sh corpus-a16` runs the full slice set (was: exit 2, zero slices).
10. **The payoff, part 2:** `dev/run.sh absdiff` shows the MAME leg PASS rather than SKIP, agreeing with
    the recorded bsnes-jg CRC `0x3794`.
11. `dev/run.sh xcheck-suite` still 51/52 (unchanged — proves no regression in the bsnes-jg path).
12. `task md -- docs/plans/2026-08-03-spc700-ipl-ssm-provisioning.md` renders cleanly.

Steps 1–4 run **now**, before the ROM arrives. Steps 5–11 unblock the moment it does.

## Step 5 — the IAM user (separate, follow-on)

Mint `65816-terraform` in account `353144603271` per `~/CLAUDE.md`'s per-project-IAM rule, scoped to
`ssm:GetParameter` + `ssm:PutParameter` on `/llvm-mos-65816/*` and `kms:Decrypt` on the `aws/ssm` key —
nothing else. The `/iam-bootstrap` skill covers this shape. Until it lands, the stopgap profile is
documented in the failure message, not hidden.

## Deliberately not doing

**Extracting the value out of the GitHub Actions secret.** A workflow could echo it somewhere
retrievable, and every asset involved belongs to the user — but it defeats a control GitHub designed to
be one-way, and the payload is copyrighted Nintendo firmware. Once SSM holds the IPL the GitHub secret
becomes a *derived* copy, and the two can be re-synced from SSM in the correct direction:
`gh secret set SNES_SPC700_ROM_B64 < <(aws ssm get-parameter … --query Parameter.Value --output text)`.
