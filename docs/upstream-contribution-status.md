# Upstream contribution status — what's drafted and pending to post

**Last updated:** 2026-06-19 (DWARF *test+docs* promoted Future→Ready — both halves now drafted; GitHub
open-count last verified 2026-06-17, see *Verified state* + *Refresh* below).

A standing snapshot of every upstream-facing contribution from this fork: what is **drafted and ready to
post**, what is **future/blocked**, and what GitHub actually shows right now. All posting is **user-triggered**
(the toolchain build + review burden lives with a human); this doc is the queue, one command per row.

## TL;DR

- **Ready to post now: 2 PRs + 2 issues + 1 design note** — five artifacts, all drafted, all one command/paste away.
  Strictly *PRs*, that's **two** (F4; and the DWARF step-6 test+docs).
- **Open on GitHub right now: 0.** We have **never** opened a PR or issue against `llvm-mos/llvm-mos` yet.
- **Future / blocked (not yet draftable): 2** — the #320 five-address-space PR (ABI-blessing-gated) and the
  llvm-mos-sdk#415 engagement (someone else's existing PR).
- **Hygiene: 1 stale fork branch** to delete (`revert-540-…`, references an already-merged upstream PR).

## Ready to post now

| # | Item | Type | What it does | Drafted at | Branch |
|---|------|------|--------------|-----------|--------|
| 1 | **F4** — `mos-late-opt` TYX/TXY dead-flag fix | **PR** | Clears dead/kill flags when rewriting `LDImm`→TYX/TXY (verifier reject on reentrant `+mos-a16`) | [`docs/321-upstream-late-opt-txy-pr.md`](321-upstream-late-opt-txy-pr.md) | `wbniv:mos-late-opt-txy-dead-flag` (pushed) |
| 2 | **P3** — `reentrant` can't force the soft stack | **issue** | Latent footgun: `__attribute__((reentrant))` is a no-op for non-recursive fns (MOSNonReentrant re-stamps `nonreentrant`) | [`docs/321-upstream-reentrant-soft-stack-issue.md`](321-upstream-reentrant-soft-stack-issue.md) | n/a (issue) |
| 3 | **#320** — far-pointer design note | **note** | Opens the five-address-space ABI-blessing discussion (a Discord/#320 post, not a code change) | [`docs/320-upstream-far-pointer-note.md`](320-upstream-far-pointer-note.md) | n/a (note) |
| 4 | **scavenger N/Z-liveness** — `saveScavengerRegister` asserts N/Z dead | **issue** | Upstream crash: a compare/ALU flag live across a frame-vreg spill → illegal `STImag8 $p` (no fork patch — maintainer territory) | [`docs/321-upstream-scavenger-nz-issue.md`](321-upstream-scavenger-nz-issue.md) | n/a (issue) |
| 5 | **DWARF step 6** — 65816 DWARF lit test + `<output>.elf` doc note | **PR** | ROADMAP step 6: pins verified DWARF shapes + documents the undocumented debug-companion `.elf` | [lit](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) · [note](321-upstream-dwarf-output-elf-companion.md) | n/a (not pushed yet) |

### 1 — F4 PR (a code-change PR; #5 DWARF is the other)

Branch `wbniv/llvm-mos:mos-late-opt-txy-dead-flag` (commit `f690dc886`, branched from `c798c3141`, a clean
ancestor of upstream `main`) is pushed; the body is drafted. Also carried locally as
`patches/llvm-mos/0003-late-opt-txy-dead-flag.patch` (drop once merged + the vendor pin bumps). Open it:

```
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-txy-dead-flag --base main \
  --title "[MOS] mos-late-opt: clear dead/kill flags when rewriting LDImm to TYX/TXY" \
  --body-file docs/321-upstream-late-opt-txy-pr.md   # strip the status/metadata preamble first
```

### 2 — P3 issue (an issue, **not** a PR)

Source-verified write-up; **no fork patch** (issue only — the safe behaviour for ordinary C is already
correct). File it:

```
gh issue create --repo llvm-mos/llvm-mos \
  --title "[MOS] __attribute__((reentrant)) is a no-op for non-recursive functions — cannot force the soft stack" \
  --body-file docs/321-upstream-reentrant-soft-stack-issue.md   # strip the status block first
```

### 3 — #320 far-pointer design note (a post, not a PR)

Drafted and ready; the manual step is posting it to the llvm-mos Discord / issue #320
(@asiekierka / @mysterymath) to open the ABI-blessing discussion. This **unblocks** the future #320 PR below.

### 4 — register-scavenger N/Z-liveness issue (an issue, **not** a PR)

Source-verified + asserts-build-confirmed write-up of an **upstream** crash:
`MOSRegisterInfo::saveScavengerRegister` asserts N/Z dead at every scavenging point, but a
compare/ALU flag can be live across a frame-vreg spill (readily hit by 16-bit-accumulator codegen)
→ illegal `STImag8 $p`. **No fork patch** (issue only; the fix touches the generic scavenger
contract and is regression-sensitive — left to maintainers). Deterministic repro included; **fix-directions
sharpened 2026-06-19** (feasibility re-probe: `P` has no GPR spill home and `PHP`/`PLP` can't bracket it
across an unbalanced push/pull range — so the obvious fix needs a stack-relative restore or a flag-safe
spill point). File it:

```
gh issue create --repo llvm-mos/llvm-mos \
  --title "[MOS] Register scavenger asserts N/Z dead (saveScavengerRegister) — violated when a compare/ALU flag is live across a frame-vreg spill" \
  --body-file docs/321-upstream-scavenger-nz-issue.md   # strip the status block first
```

Full internal analysis: [`docs/investigations/65816-a16-scavenger-nz-liveness.md`](investigations/65816-a16-scavenger-nz-liveness.md).

### 5 — DWARF step-6 *test + docs* PR

The 65816 DWARF *content* is already correct upstream — **no codegen change** (Step-1 audit clean,
2026-06-18; re-verified 2026-06-19). Two drafted halves guard + document it, bundled as one PR:

- **test:** [`dev/lit/DebugInfo/MOS/dwarf-65816.ll`](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) — pins the
  65816 DWARF shapes (`addr_size 0x04`, `DW_AT_frame_base = DW_OP_regx RS0`, a 16-bit local in an
  imaginary-register pair `DW_OP_regx RSn`, line table, `--verify` clean). Verified by its manual
  `llc | llvm-dwarfdump | FileCheck` pipeline (full `llvm-lit` needs `count`/`not`, unbuilt here). Drops
  into `llvm/test/DebugInfo/MOS/`.
- **docs:** [`docs/321-upstream-dwarf-output-elf-companion.md`](321-upstream-dwarf-output-elf-companion.md)
  — documents that `ld.lld` writes a `<output>.elf` DWARF companion beside the flat ROM for **any**
  `OUTPUT_FORMAT { FULL/TRIM }` link (undocumented today; it's the artifact a source-level debugger loads).
  Proposes a documentation-only `lld/ELF/Writer.cpp` comment + an SDK doc sentence — **no behavior change**.

The durable in-repo guard is **`dev/run.sh dwarf`** (7/7, real `--config -g` build, companion-ELF
asserted). **No fork patch carried** (the lit test is a drop-in; the doc comment is maintainer territory).
Post it (after dropping the test in + adding the comment in a clean `wbniv/llvm-mos` checkout off `main`):

```
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-dwarf-65816-test-docs --base main \
  --title "[MOS] DebugInfo/MOS: 65816 DWARF test + document the <output>.elf companion" \
  --body-file docs/321-upstream-dwarf-output-elf-companion.md   # strip the status block first
```

May also split: the lit test alone is a pure backend-test PR; the `<output>.elf` documentation is a
separate `lld`/SDK docs change. See [DWARF round-trip plan, Step 6](plans/2026-06-18-dwarf-round-trip-roadmap-step-6-drmon-tie-in.md).

## Future / blocked (not yet postable — do **not** count these as pending)

- **#320 five-address-space model + PR.** The real far-pointer codegen PR (asiekierka's 32-bit-default /
  packed 24-bit / zero-bank / abs-16 layout). Blocked on maintainer **ABI blessing** — gated behind posting
  the #320 design note above. Not drafted as a PR yet.
- **llvm-mos-sdk#415 reconciliation.** Engage @Phillip-May's existing stalled SNES-target draft PR (build on
  his `snesxc` reg lib + multi-bank linker, contribute our native-mode crt0 + dual-emulator CI on top). This
  is *engaging someone else's PR*, not opening our own. Strategy in
  [`docs/415-snes-target-reconciliation.md`](415-snes-target-reconciliation.md).

> *(The ROADMAP-step-6 DWARF **test + docs** item moved up to **Ready to post now #5** on 2026-06-19 —
> both halves are now drafted: the staged lit test + the `<output>.elf` doc note.)*

## Hygiene — stale fork branch

`wbniv/llvm-mos:revert-540-fix/soft-stack-spill-crash` is a leftover **revert** branch of **upstream PR
#540** ("fix(MOS): use reserved RS8 for soft stack spill scratch register"), which was **MERGED upstream on
2026-01-26**. **No open PR uses the branch** — it is not a pending contribution of ours, just cruft. Safe to
delete:

```
gh api -X DELETE repos/wbniv/llvm-mos/git/refs/heads/revert-540-fix/soft-stack-spill-crash
```

## Verified state (GitHub, 2026-06-17)

```
$ gh pr list --repo llvm-mos/llvm-mos --author wbniv --state all
(empty — we have never opened a PR upstream)

$ gh api repos/wbniv/llvm-mos/branches --jq '.[].name' | grep -v '^main$'
mos-late-opt-txy-dead-flag                 # F4 — pending PR
revert-540-fix/soft-stack-spill-crash      # stale revert of merged upstream #540

$ gh pr view 540 --repo llvm-mos/llvm-mos --json number,title,state,mergedAt
{"number":540,"title":"fix(MOS): use reserved RS8 for soft stack spill scratch register",
 "state":"MERGED","mergedAt":"2026-01-26T22:23:07Z"}
```

## Refresh this snapshot

```
gh pr list --repo llvm-mos/llvm-mos --author wbniv --state all      # what we've opened upstream
gh api repos/wbniv/llvm-mos/branches --jq '.[].name'               # pushed branches = candidate PRs
ls docs/32*upstream* docs/320-upstream*                            # drafted artifacts in the repo
```

Cross-check the drafted-artifacts list against the TODO **Upstream / Contribution** section; each `*upstream*`
doc here should map to a TODO item, and vice-versa.
