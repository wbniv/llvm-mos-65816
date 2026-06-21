# Upstream contribution status — what's drafted and pending to post

**Last updated:** 2026-06-21 (the **#320 far-pointer fork-side implementation body** grew to feature-complete
— clang `far`/`long_call` attribute (F2), typed `far_fn_t` variable, `sizeof(far*)==4`, far_indir crash fix;
pushed `origin/wt/320-far-followups`. Still ABI-blessing-gated, so it stays *Future/blocked*, not a new
ready-to-post item. Previously 2026-06-20: added the #321 CC frame-ABI design note (Ready-to-post #6); DWARF
branch `wbniv:mos-dwarf-65816-test-docs` pushed `0ae9415`; GitHub open-count last verified 2026-06-17, see
*Verified state* + *Refresh* below).

A standing snapshot of every upstream-facing contribution from this fork: what is **drafted and ready to
post**, what is **future/blocked**, and what GitHub actually shows right now. All posting is **user-triggered**
(the toolchain build + review burden lives with a human); this doc is the queue, one command per row.

## TL;DR

- **Ready to post now: 2 PRs + 2 issues + 3 design notes** — seven artifacts, all drafted, all one command/paste away.
  Strictly *PRs*, that's **two** (F4; and the DWARF step-6 test+docs).
- **Open on GitHub right now: 0.** We have **never** opened a PR or issue against `llvm-mos/llvm-mos` yet.
- **Future / blocked (not yet draftable): 2** — the #320 five-address-space PR (ABI-blessing-gated) and the
  llvm-mos-sdk#415 engagement (someone else's existing PR).
- **Hygiene: 1 leftover fork branch** (`revert-540-…`) **retained by preference** — user keeps fork
  branches until merged upstream; **do not auto-propose deletion**.

## Ready to post now

| # | Item | Type | What it does | Drafted at | Branch |
|---|------|------|--------------|-----------|--------|
| 1 | **F4** — `mos-late-opt` TYX/TXY dead-flag fix | **PR** | Clears dead/kill flags when rewriting `LDImm`→TYX/TXY (verifier reject on reentrant `+mos-a16`) | [`docs/321-upstream-late-opt-txy-pr.md`](321-upstream-late-opt-txy-pr.md) | `wbniv:mos-late-opt-txy-dead-flag` (pushed) |
| 2 | **P3** — `reentrant` can't force the soft stack | **issue** | Latent footgun: `__attribute__((reentrant))` is a no-op for non-recursive fns (MOSNonReentrant re-stamps `nonreentrant`) | [`docs/321-upstream-reentrant-soft-stack-issue.md`](321-upstream-reentrant-soft-stack-issue.md) | n/a (issue) |
| 3 | **#320** — far-pointer design note | **note** | Opens the five-address-space ABI-blessing discussion (a Discord/#320 post, not a code change). **Updated 2026-06-21** with the Phase 0/3 corrections: retracts the pow2-pointer-size premise (real reason = MVT has no i24), the C1 single-datalayout finding (`0=far-default` foreclosed → a clang flag), and the packed-24 representable-but-deferred position. Posting-ready (user-triggered). | [`docs/320-upstream-far-pointer-note.md`](320-upstream-far-pointer-note.md) | n/a (note) |
| 4 | **scavenger N/Z-liveness** — `saveScavengerRegister` asserts N/Z dead | **issue** | Upstream crash: a compare/ALU flag live across a frame-vreg spill → illegal `STImag8 $p` (no fork patch — maintainer territory) | [`docs/321-upstream-scavenger-nz-issue.md`](321-upstream-scavenger-nz-issue.md) | n/a (issue) |
| 5 | **DWARF step 6** — 65816 DWARF lit test + `<output>.elf` doc note | **PR** | ROADMAP step 6: pins verified DWARF shapes + documents the undocumented debug-companion `.elf` | [lit](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) · [note](321-upstream-dwarf-output-elf-companion.md) | `wbniv:mos-dwarf-65816-test-docs` (pushed `0ae9415`) |
| 6 | **#321 CC frame-ABI** — measured frame-model evaluation | **note** | Implementation-backed CC evidence: DP-window/stack-relative are feasible but NULL on real code (locals are `__rc`-resident → frames ≈unused); keep the soft static stack, by measurement | [`docs/321-upstream-cc-frame-abi-note.md`](321-upstream-cc-frame-abi-note.md) | n/a (note) |
| 7 | **#320 far-CC** — measured ABI evaluation (far ptr across a call) | **note** | Implementation-backed CC evidence: all 4 ABIs built behind `+mos-farcc-*` + measured (bytes + round-trips/frame) on MAME+bsnes-jg → **Imag32 wins decisively** (70 B/50441; smallest *and* fastest). Far ptr should pass/return whole in one 4-byte imaginary-register unit, by measurement. **Follow-up to #3** — post after the design note opens the conversation. Shipped as `0004` in-fork. | [`docs/320-upstream-far-cc-measurement-note.md`](320-upstream-far-cc-measurement-note.md) | n/a (note) |

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
Branch `wbniv/llvm-mos:mos-dwarf-65816-test-docs` (commit `0ae9415`, branched from `c798c3141`, upstream `main`) is pushed. Post it:

```
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-dwarf-65816-test-docs --base main \
  --title "[MOS] DebugInfo/MOS: 65816 DWARF test + document the <output>.elf companion" \
  --body-file docs/321-upstream-dwarf-output-elf-companion.md   # strip the status block first
```

May also split: the lit test alone is a pure backend-test PR; the `<output>.elf` documentation is a
separate `lld`/SDK docs change. See [DWARF round-trip plan, Step 6](plans/2026-06-18-dwarf-round-trip-roadmap-step-6-drmon-tie-in.md).

### 6 — #321 CC frame-ABI design note (a post, not a PR)

Implementation-backed evidence for the #321 calling-convention discussion: we built the feasibility proof and
measured the *opportunity* for a per-frame hardware-stack ABI (TCD direct-page window / stack-relative) vs the
soft static stack. Finding: **feasible but NULL** — 0/13 realistic functions would benefit, because llvm-mos
keeps locals register-resident in `__rc` (frames ≈ unused). The note argues to keep the soft static stack *by
measurement*, and documents why the textbook commercial DP-frame doesn't transplant onto the fixed-ZP
imaginary-register model. **No code change** (the off-by-default `+mos-dp-frame`/`+mos-sr-frame` spike was not
landed — it failed the go/no-go bar). Reproducible via `dev/frameabi-census.sh` + `dev/run.sh frameabi_a0`.
Post it (issue comment and/or the Discord CC thread):

```
gh issue comment 321 --repo llvm-mos/llvm-mos --body-file docs/321-upstream-cc-frame-abi-note.md   # strip the status block first
```

Full internal record: [frame-ABI study plan §Outcome](plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).

### 7 — #320 far-CC measurement note (a post, not a PR)

Implementation-backed evidence for how a far (addrspace 2) pointer should cross a call. We built **all four**
plausible ABIs behind off-by-default `+mos-farcc-*` features and measured them on the same realistic
round-trip (a far ptr returned from one `noinline`, passed into another, dereferenced across a bank), gated
`0xF3` on MAME + bsnes-jg: **(a) Imag32 70 B/50441 · (b) Imag16+bank 86 B/41385 · (c) A:X+Y 102 B/43572 ·
(d) soft-stack 174 B/30626**. **Imag32 wins on both axes**, so far-ptr-across-call ships **Imag32 by
default** in-fork (patch `0004`); the others are retained only as the measured spike. **Follow-up to #3** —
post after the design note opens the conversation. Reproducible via `dev/measure-far-cc.sh` +
`dev/farcc_{imag32,split,axy,stack}.sh` + `dev/probe-cycles.lua`. Post it (Discord/#320 thread):

```
gh issue comment 320 --repo llvm-mos/llvm-mos --body-file docs/320-upstream-far-cc-measurement-note.md   # strip the status block first
```

Full internal record: [far-cc study + land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md).

## Future / blocked (not yet postable — do **not** count these as pending)

- **#320 five-address-space model + PR.** The real far-pointer codegen PR (asiekierka's 32-bit-default /
  packed 24-bit / zero-bank / abs-16 layout). Blocked on maintainer **ABI blessing** — gated behind posting
  the #320 design note above. Not drafted as a PR yet. **The fork-side implementation body is now large and
  feature-complete (2026-06-21)** and would form the bulk of this PR once unblocked — now **landed on `main`
  (2026-06-21)** as `patches/llvm-mos/0001` (a16-free) + `0004` (far-ptr CC, Imag32 winner) + `0005` (the lone
  a16-context-entangled `MOSLegalizerInfo` PF-as-value hunk); round-trip-proven against `wt/320-far-followups`
  (also pushed `origin/wt/320-far-followups`):
  - **far calls (b):** far→near mixed-banking via the bank-0 thunk `__call_near_from_far` (shipped to `main`).
  - **far function pointers (a):** the p2-value sub-project (Layers 1–3 + Gap A/B), the `jsl __call_indir_far`
    indirect-call mechanism, **and the clang front-end (F2):** a MOS **`far`/`long_call`** function/type
    attribute (`MOSFarCall`) — notably it reuses the MIPS `long_call`/`far` GNU spelling via a **shared
    `ParseKind="LongCall"`** (the same multi-target pattern `interrupt` uses), and a `CGExpr`/`CGExprScalar`
    rewrite to the `store @__mos_far_target` + `call @__call_indir_far` shape. Both a **direct** `far` call
    and a **stored** `far_fn_t fp = far_leaf; fp(x)` pointer work in single-file C (a `far` bit on
    `FunctionType::ExtInfo` → `ptr addrspace(2)`).
  - **far-pointer sizing:** `getPointerWidthV(AS2)`→32 + a `getTypeInfoImpl` arm so `sizeof(FAR*) ==
    sizeof(far_fn_t) == 4` (matches the `p2:32:8` IR width).
  - **a crash fix worth flagging upstream-adjacent:** `isFarSymbol` was treating any `.far*`-sectioned
    symbol as far (24-bit), crashing when a `.far_rodata` datum's address is taken as a *near* pointer;
    restricted to **functions** (`isa<Function>`). This is a fix to fork-only far machinery, so it rides the
    same #320 PR rather than standing alone.
  Verified end-to-end on **MAME + bsnes-jg** (the whole far suite, 12 ROMs) + corpus 7/7 + csmith 0-mismatch.
  Still ABI-blessing-gated; the `far`/`long_call` attribute spelling-sharing design is a candidate talking
  point for the #320 note when it's posted.
- **llvm-mos-sdk#415 reconciliation.** Engage @Phillip-May's existing stalled SNES-target draft PR (build on
  his `snesxc` reg lib + multi-bank linker, contribute our native-mode crt0 + dual-emulator CI on top). This
  is *engaging someone else's PR*, not opening our own. Strategy in
  [`docs/415-snes-target-reconciliation.md`](415-snes-target-reconciliation.md).
- **Native 65816 16-bit codegen (`+mos-a16` / `+mos-xy16`) + the index-width register model.** The whole #321
  native-16-bit slice is fork-only — upstream's `W65816` is **8-bit / emulation-mode** (`FeatureAccum16` /
  `FeatureIndex16` are *not* implied by `FamilyW65816`; `Ac16/Xc16/Yc16/XH/YH` and `MOSInsertREPSEP` are
  net-new in `0002`). The **M2** goal is to upstream this. A correctness prerequisite surfaced 2026-06-20: the
  16-bit **index-register model must encode the hardware invariant** that narrowing the 65816's *single shared
  index-width flag* zeroes `XH`/`YH` — so a 16-bit index value can't be live across an 8-bit-index op (else
  its high byte is silently lost; the seed 247/445 miscompile). Root cause + fix scoping:
  [`docs/investigations/65816-xy16-index16-highbyte-clobber.md`](investigations/65816-xy16-index16-highbyte-clobber.md).
  Fixed fork-side as a **structural hardware invariant** (not an `xy16` special-case); carry that model into
  the upstream contribution. Blocked on the broader native-16-bit upstreaming (large; maintainer ABI alignment).

> *(The ROADMAP-step-6 DWARF **test + docs** item moved up to **Ready to post now #5** on 2026-06-19 —
> both halves are now drafted: the staged lit test + the `<output>.elf` doc note.)*

## Hygiene — leftover fork branch (retained by preference)

`wbniv/llvm-mos:revert-540-fix/soft-stack-spill-crash` is a leftover **revert** branch of **upstream PR
#540** ("fix(MOS): use reserved RS8 for soft stack spill scratch register"), which was **MERGED upstream on
2026-01-26**. No open PR uses it, so it is not a pending contribution of ours.

**Standing policy (user, 2026-06-21): keep fork branches around — do not auto-propose deleting them.** The
user retains fork branches as a habit (a safety net until the related work is merged upstream); this one is
**left in place**. Only delete on an explicit, case-by-case request. Note the corner case for the record:
this is a *revert* of an *already-merged* PR, so "until merged upstream" is technically already satisfied —
but it stays unless the user says otherwise. The one-liner, if they ever opt in:

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
