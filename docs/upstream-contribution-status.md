# Upstream contribution status — what's drafted and pending to post

**Last updated:** 2026-06-26 (**far-pointer-PHI legalization fix** — a far (addrspace 2) pointer used as a loop
induction variable (`for(;n;p++) *p=…`) forms a `G_PHI` of a far (p2) pointer; the MOS legalizer made `G_PHI`
legal only for `{s1,s8,p0,p1}`, NOT the 32-bit p2, so the backend ABORTED (`unable to legalize ... G_PHI (p2)`)
on valid C. This **resolves the follow-up gap the far-memops entry below noted** (the reason `mem-far.c` is written
index-style). Fix = `MOSLegalizerInfo::legalizePhi` (`.customFor({PF})` on the `G_PHI` rule + a `legalizeCustom`
arm): custom-legalize a far-pointer phi to an **s32 phi** — ptrtoint each incoming value in its predecessor,
inttoptr the result back to p2 after the phi — the same ptrtoint/inttoptr bridge `legalizePtrAdd`/far load+store
use; the s32 phi reuses the standard `narrowScalar`→bytes path. Purely additive (other phi types untouched), no
generic-LLVM change. Carried as fork patch **`0014-321-far-ptr-phi-legalize`** + `dev/regen-patch-0014.sh`, gated
by `dev/run.sh far_loop` (`corpus_result==0xC9`, MAME `-Os`/`-O2` + bsnes-jg via `xcheck`; the compile gate IS the
crash regression-guard). A self-contained **MOS-backend correctness fix, upstream-worthy** once #320's AS2 is
blessed — folds into the Future/blocked #320/#321 body, **not** a new ready-to-post row (AS2 isn't
upstream-standalone-testable). No GitHub state change (no posting) — #561/#562/#563 still OPEN.) Previously
2026-06-26 (**far addrspace-2 memset/memcpy/memmove silent wrong-bank fix** — a far memop the
backend can't inline-expand (variable size, or constant size over `MOSLegalizerInfo`'s `SizeLimit`) fell through
`legalizeMemOp` into the generic `createMemLibcall`, which called the **near** runtime (`__memset`/`memcpy`,
16-bit `char*`) while passing the 32-bit far pointer → the bank byte was silently dropped → wrong-bank store/load,
no diagnostic. Sources are NOT just the loop-idiom recognizer: clang `EmitAggregateCopy` (any far struct copy, no
size threshold), null/const init, `__builtin_mem*`, and MemCpyOpt all converge on the same path. Fix = route far
memops at the `legalizeMemOp` chokepoint to a far-aware runtime (`__memset_far`/`__memcpy_far`/`__memmove_far`,
`platforms/snes/mem-far.c`) via two static helpers (`anyFarPointerOperand` + `createFarMemLibcall`) in
`MOSLegalizerInfo.cpp`; near pointers widen to far bank `$00`. No generic-LLVM change. Carried as fork patch
**`0013-320-far-memops`**, gated by `dev/run.sh far_memops` (`corpus_result==0x74`, MAME+bsnes-jg, `-Os`/`-O2`) +
the standing far suite (`dev/run.sh xcheck`). A self-contained **MOS-backend correctness fix, upstream-worthy**
once #320's AS2 is blessed — folds into the Future/blocked #320 body, **not** a new ready-to-post row (AS2 isn't
upstream-standalone-testable). Surfaced a related backend gap noted for follow-up: a far-pointer loop induction
variable forms an unsupported `G_PHI (p2)`; the runtime is written index-style (invariant far base) to avoid it.
Upstream state unchanged — #561/#562/#563 still OPEN.) Previously 2026-06-26 (the **far array-subscript index-width fix** now has a **dedicated committed regression
gate** — `dev/run.sh farindex`: `examples/65816/farindex.c` promoted from an open repro → passing gate, a
`const FAR uint16_t tbl[]` read across banks $C1/$C2/$C3 folds `corpus_result==0x0001D8A1` on MAME + bsnes-jg.
Strengthens the test story for that fix in the Future/blocked #320 body; still **not** a new ready-to-post row
(AS2 isn't upstream-standalone-testable). Upstream state unchanged — #561/#562/#563 still OPEN.) Previously
2026-06-25 (added the **far array-subscript index-width correctness fix** to the #320 far-pointer
body — clang `CGExpr.cpp` promoted the GEP index to the default 16-bit `IntPtrTy` for every AS, truncating a far/AS2
index ≥ 32768; fix = the base pointer's per-AS index width. In `0001`; drafted
[`docs/320-upstream-far-subscript-index-fix.md`](320-upstream-far-subscript-index-fix.md); folds into the
Future/blocked #320 item below — not a new ready-to-post row (AS2 isn't upstream, so it's not standalone-testable).
Also re-verified upstream state — #561/#562/#563 all still **OPEN**, none merged; 3 fork branches intact; the
project-`main` pointer was generalized.) Previously 2026-06-24 (added the review-guide reviewer slice — [Appendix D](65816-patch-series-review-guide.md#appendix-d--upstream-bug-fixes--status)
+ `dev/upstream-status.sh` — and re-verified #561/#562/#563 still open. 2026-06-23: first upstream contributions now live — PR #562 (F4) + issue #561 + the #561
fix PR #563; *Verified state* snapshot refreshed; project repo `wbniv/llvm-mos-65816` `main` pushed to
`e39d0ed`. Also landed on `main`: **#320 far tail calls** in `0001` (`4adda8b`) — far→far `JSL;RTL` folds
to a `TailJML`/`$5C` long jump, −1 B/site — and **32-bit `long`/`int32_t` value-verified** (`a16s32`
micro-test + a gated `--s32` builtin-fuzzer track, test/tooling only); both fold into the ABI-gated fork
bodies below, not new ready-to-post rows. **Hygiene:** the leftover `revert-540-…` fork branch (stale
revert of merged #540) was deleted by the user on explicit request → 0 leftover fork branches. Previously 2026-06-22: the **#321 stage-1 native-s16 surface** is now **measured-complete** — consolidated
host-side via `dev/measure-native-s16-surface.sh`; the drafted "stage-1 native-s16 is measured-complete" evidence
paragraph lives in the [surface consolidation plan](plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md)
and is folded into the *Native 65816 16-bit codegen* Future/blocked item below — still ABI-alignment-gated, not a
new ready-to-post row. Previously 2026-06-21: the **#320 far-pointer fork-side implementation body** grew to feature-complete
— clang `far`/`long_call` attribute (F2), typed `far_fn_t` variable, `sizeof(far*)==4`, far_indir crash fix;
pushed `origin/wt/320-far-followups`. Still ABI-blessing-gated, so it stays *Future/blocked*, not a new
ready-to-post item. Previously 2026-06-20: added the #321 CC frame-ABI design note (Ready-to-post #6); DWARF
branch `wbniv:mos-dwarf-65816-test-docs` pushed `0ae9415`; GitHub open-count last verified 2026-06-17, see
*Verified state* + *Refresh* below).

A standing snapshot of every upstream-facing contribution from this fork: what is **drafted and ready to
post**, what is **future/blocked**, and what GitHub actually shows right now. All posting is **user-triggered**
(the toolchain build + review burden lives with a human); this doc is the queue, one command per row. The
reviewer-facing slice — just the **bug-fix PRs** that touch the patch stack — is
[review guide Appendix D](65816-patch-series-review-guide.md#appendix-d--upstream-bug-fixes--status)
(refreshable via [`dev/upstream-status.sh`](../dev/upstream-status.sh)).

## TL;DR

- **Ready to post now: 1 PR + 3 issues + 3 design notes** — seven artifacts (F4 PR + DP-arg issue posted
  2026-06-22; see *Open on GitHub* below). Strictly *PRs*, that's **one** (the DWARF step-6 test+docs).
- **Open on GitHub right now: 3** — [PR #562](https://github.com/llvm-mos/llvm-mos/pull/562) (F4 — TYX/TXY
  dead-flag fix), [issue #561](https://github.com/llvm-mos/llvm-mos/issues/561) (DP-arg CC), and
  [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563) (the **fix** for #561 — `Fixes #561`, auto-closes
  it on merge). #561+#562 opened 2026-06-22; #563 opened 2026-06-23. (Our first contributions upstream.)
- **Future / blocked (not yet draftable): 2** — the #320 five-address-space PR (ABI-blessing-gated) and the
  llvm-mos-sdk#415 engagement (someone else's existing PR).
- **Hygiene: 0 leftover fork branches** — `revert-540-…` (a stale revert of merged #540) was **deleted by
  the user 2026-06-23** on explicit request (re-verified gone 2026-06-24); the 3 remaining (`mos-dp-arg-cc`,
  `mos-late-opt-txy-dead-flag`, `mos-dwarf-65816-test-docs`) are **active** PR/queue branches. Standing
  policy unchanged: keep fork branches until merged upstream; **do not auto-propose deletion** (delete only
  on explicit request).

## Ready to post now

| # | Item | Type | What it does | Drafted at | Branch |
|---|------|------|--------------|-----------|--------|
| 1 | ✅ **POSTED** — **F4** — `mos-late-opt` TYX/TXY dead-flag fix | **PR** | Clears dead/kill flags when rewriting `LDImm`→TYX/TXY (verifier reject on reentrant `+mos-a16`) | [`docs/321-upstream-late-opt-txy-pr.md`](321-upstream-late-opt-txy-pr.md) | [**PR #562**](https://github.com/llvm-mos/llvm-mos/pull/562) (opened 2026-06-22) |
| 2 | **P3** — `reentrant` can't force the soft stack | **issue** | Latent footgun: `__attribute__((reentrant))` is a no-op for non-recursive fns (MOSNonReentrant re-stamps `nonreentrant`) | [`docs/321-upstream-reentrant-soft-stack-issue.md`](321-upstream-reentrant-soft-stack-issue.md) | n/a (issue) |
| 3 | **#320** — far-pointer design note | **note** | Opens the five-address-space ABI-blessing discussion (a Discord/#320 post, not a code change). **Updated 2026-06-21** with the Phase 0/3 corrections: retracts the pow2-pointer-size premise (real reason = MVT has no i24), the C1 single-datalayout finding (`0=far-default` foreclosed → a clang flag), and the packed-24 representable-but-deferred position. Posting-ready (user-triggered). | [`docs/320-upstream-far-pointer-note.md`](320-upstream-far-pointer-note.md) | n/a (note) |
| 4 | ✅ **FIXED** — **scavenger live-`$p`** — `saveScavengerRegister` can't preserve a live `$p` across an unbalanced stack range | **fix PR** | Upstream crash (was an issue-with-no-fix): a `+mos-a16`/`+mos-xy16` compare keeps N/Z live across a frame-carry spill, forcing the whole `$p` preserved across an *unbalanced* range, but `$p` has no GPR home → illegal `STImag8 $p` + undefined-`$p` `PH $p`. **Fix** = route `$p` hard-stack-neutrally through a dead index reg into `RC17` + drop the stale `assertNZDeadAt`; carried as fork patch `0011` (`a16scavnz.c` now a `0x22A6` positive gate, both emulators, asserts-clean). | [PR body](upstream-scavenger-live-p-pr.md) · patch `patches/llvm-mos/0011-mos-scavenger-live-p-save.patch` | not yet pushed (`wbniv:mos-scavenger-live-p-save` to mint) |
| 5 | **DWARF step 6** — 65816 DWARF lit test + `<output>.elf` doc note | **PR** | ROADMAP step 6: pins verified DWARF shapes + documents the undocumented debug-companion `.elf` | [lit](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) · [note](321-upstream-dwarf-output-elf-companion.md) | `wbniv:mos-dwarf-65816-test-docs` (pushed `0ae9415`) |
| 6 | **#321 CC frame-ABI** — measured frame-model evaluation | **note** | Implementation-backed CC evidence: DP-window/stack-relative are feasible but NULL on real code (locals are `__rc`-resident → frames ≈unused); keep the soft static stack, by measurement | [`docs/321-upstream-cc-frame-abi-note.md`](321-upstream-cc-frame-abi-note.md) | n/a (note) |
| 7 | **#320 far-CC** — measured ABI evaluation (far ptr across a call) | **note** | Implementation-backed CC evidence: all 4 ABIs built behind `+mos-farcc-*` + measured (bytes + round-trips/frame) on MAME+bsnes-jg → **Imag32 wins decisively** (70 B/50441; smallest *and* fastest). Far ptr should pass/return whole in one 4-byte imaginary-register unit, by measurement. **Follow-up to #3** — post after the design note opens the conversation. Shipped as `0004` in-fork. | [`docs/320-upstream-far-cc-measurement-note.md`](320-upstream-far-cc-measurement-note.md) | n/a (note) |
| 8 | ✅ **POSTED + FIXED** — **DP-arg CC** — `addrspace(1)` 8-bit pointer argument in a 16-bit register | **issue + fix PR** | Upstream crash: `CCIfPtr` (MOSCallingConv.td:65) assigns *every* pointer arg to a 16-bit `RS` pair, so an 8-bit `addrspace(1)` (direct-page) pointer arg → illegal `(p1)=COPY $rs`. **Fix** = a `CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2..RC15]>>` rule (8-bit slot) + a `-verify` CodeGen test; spike-validated (5 shapes, corpus 7/7), carried as fork patch `0008`. | [issue body](320-upstream-dp-arg-cc-issue.md) · [PR body](320-upstream-dp-arg-cc-pr.md) | [**#561**](https://github.com/llvm-mos/llvm-mos/issues/561) (2026-06-22) → fixed by [**PR #563**](https://github.com/llvm-mos/llvm-mos/pull/563) (`wbniv:mos-dp-arg-cc`, 2026-06-23) |
| 9 | **coalesce-rotate-Ac** — silent miscompile: rotate value coalesced into A-only `Ac` | **issue + fix PR** | Default-8bit miscompile (no `+mos-a16`): the register coalescer merges two shift/rotate-referenced values into the A-only `Ac` class, stranding a loop-carried CRC byte in `Y` while the back-edge `ROL` reads a stale `A` (inlined CRC16 bit loop under pressure). Both `-verify-machineinstrs`/`-verify-coalescing` clean. **Fix** = `MOSRegisterInfo::shouldCoalesce` refuses the join (`NewRC==Ac` ∧ both operands rotate-referenced) + a `-run-pass=register-coalescer` lit test; carried as fork patch `0010`, validated (repro `0xE60E`→`0xF56C`, corpus 7/7, torture 30/30, csmith 54/60 0-mismatch). | [PR body](upstream-coalesce-rotate-ac-pr.md) · patch `patches/llvm-mos/0010-coalesce-rotate-ac.patch` | not yet pushed (`wbniv:mos-coalesce-rotate-ac` to mint) |
| 10 | **`LDCImm` set lowering** — `MOSMCInstLower` asserts a single carry-set encoding | **fix PR** | Upstream `llvm_unreachable("Unexpected LDCImm immediate")` (asserts) / silent NDEBUG-UB: `LDCImm` lowered only `0`/`-1`, but a *set* i1 carry can arrive as `1` (a 16-bit `SBC` carry-in). Reproduces on a plain `+mos-a16` 16-bit subtract. Surfaced by `0011` (compilation reached MC lowering once the scavenger stopped crashing). **Fix** = lower any nonzero i1 as `SEC` (differential-neutral); carried as fork patch `0012`. | [PR body](upstream-ldcimm-set-lowering-pr.md) · patch `patches/llvm-mos/0012-mos-ldcimm-set-lowering.patch` | not yet pushed (`wbniv:mos-ldcimm-set-lowering` to mint) |
| 11 | ⛔ **RETRACTED — MISDIAGNOSIS (do NOT post)** — "LTO + `+mos-a16` bitmask-loop early exit" | ~~issue~~ | **Disproven 2026-06-28** by a controlled rebuild experiment ([plan](plans/2026-06-28-321-verify-lto-a16-bitmask-early-exit-diagnosis.md)). The `cmp #$10` is the loop's `q->n < UPQ_MAX_JOBS` guard (`UPQ_MAX_JOBS=16=0x10`), **not** the shift counter `r`: overriding `-DUPQ_MAX_JOBS=20` moves the constant to `cmp #$14` (tracks the macro). The `jmp rts` is the correct per-vblank DMA-budget exit (≤16 jobs/frame; 28 rows over 2 frames); the real `r<28` bound `cpy #$1c` is present. No row-skip miscompile exists. The original demo stall is a *separate, unverified* question (possible 32-bit `==0` LTO miscompile or frame ordering) → would need a **fresh, correctly-characterized** issue, not this one. | [issue body (banner-retracted)](321-upstream-lto-a16-bitmask-loop-early-exit-issue.md) | n/a — not to be posted |
| 12 | **coalesce-rc-undef** — verifier reject: call-clobbered `$rcN` value coalesced into a pair across the clobber | **fix PR** | `+mos-a16`/`+mos-xy16` under pressure: the register coalescer folds a value read straight out of a call-clobbered imaginary register (`vreg = COPY $rcN`) into an `Imag16` pair (sub-register copy) that outlives the clobbering call → the allocator re-binds the pair to `$rcN` across the clobber → disconnected `$x = COPY $rcN` def→use (`-verify-machineinstrs`: "Using an undefined physical register"; runs correctly, latent hazard). **Fix** = `MOSRegisterInfo::shouldCoalesce` refuses the join (`NewRC==Imag16` ∧ sub-register ∧ an operand's unique def is `COPY $rcN` live across a call clobbering `$rcN` via `checkRegMaskInterference`) + a `-run-pass=register-coalescer` lit test. Correctness-safe by construction; 4/34 corpus programs change (all `-verify` clean + differential green), 30 byte-identical. Validated: newton `0x4D8B` unchanged (MAME+bsnes-jg), `rcundef.c`+`newton_step` verify clean `-O0/-O1/-Os` a16+xy16. Carried as fork patch `0002` (cpp) + `0015` (lit test). **Scope:** a second, distinct cause (RA binding a *pure-virtual* value to a clobbered `$rc` pair — lsystem/newton-`-O1`) is NOT fixed by this guard; deferred to an RA-interference fix. | [PR body](upstream-coalesce-rc-undef-pr.md) · patches `0002` + `patches/llvm-mos/0015-321-coalesce-rc-undef-test.patch` | not yet pushed (`wbniv:mos-coalesce-rc-undef` to mint) |
| 13 | **rc-undef-ra-pure-virtual** — verifier reject: dead read of an `undef` `Imag16` sub-lane after RA (cause #2) | **issue** | The *second* distinct cause of the same "Using an undefined physical register" message — **not** a coalescer issue. A 16-bit `__mulsi3` argument built with the `undef %N.sublo:imag16 = COPY …` idiom (high lane undef) is RA-assigned a `$rc` pair; the undef high lane is tracked live to a **dead** full-pair read (`$x = COPY $rcN`, `$x` immediately overwritten) but no instruction materializes it. Lowering the virtual sub-register read to the physical `$rcN` **loses the `undef` flag**, so the dead read trips the verifier. Code-correct (lsystem `0x79C3`, newton `0x4D8B`). Generic-RA / sub-register-undef-liveness; candidate fixes (propagate `undef` onto the physreg read, or DCE the dead extract) are toolchain-wide and need a full regression sweep — **filed as an issue**, not patched blindly. Repro: `lsystem_sim.c` `main`, `newton_sim.c` `newton_gate_crc` `-O1`. Tracked downstream as `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]` (lsystem XFAIL). | [issue body](upstream-rc-undef-ra-pure-virtual-issue.md) | n/a (issue) |

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

**Now also carries a "Code model: near vs far" section** (added 2026-06-22) — two distinct artifacts on one
topic: (a) **compiler-side framing** (llvm-mos #320): near = `small`/`JSR` is the default, far = `medium`/`large`
is per-symbol opt-in, so **no `-mcmodel` codegen mode is warranted**; (b) **SDK-side enforcement**
(llvm-mos-sdk): the SNES near-code budget (`$8000–$FFAF`, 32688 B) is a *link-time contract* — `platforms/snes`
+ `snes-far` `link.ld` carve the header/vectors into a `romhdr` region so an over-budget link fails with
`region 'rom' overflowed by N bytes` (landed in-fork, ROM byte-identical for in-budget programs;
[plan](plans/2026-06-22-snes-near-code-budget-and-code-model.md)). (a) rides this note; (b) is an
llvm-mos-sdk-side change carried in our platform.

### 4 — register-scavenger live-`$p` fix (a **PR** now — was an issue) + the `LDCImm` lowering fix it surfaced

**FIXED 2026-06-26** (supersedes the issue-only draft). Two pristine-upstream fork patches, each
independently postable, each drops from the stack on merge:

- **`0011-mos-scavenger-live-p-save.patch`** — `MOSRegisterInfo::saveScavengerRegister` assumed N/Z dead at
  every scavenge point and that a live `$p` only needs preserving across a *balanced* range; both break under
  16-bit-accumulator flag live ranges → illegal `STImag8 $p` (`$p is not a GPR`) + undefined-`$p` `PH $p`.
  Fix: route `$p` hard-stack-neutrally through a dead 8-bit index register into `RC17` for the unbalanced
  case, flag the no-reaching-def `PHP` `undef`, drop the stale `assertNZDeadAt`, widen
  `canSaveScavengerRegister(P)`. PR body: [`docs/upstream-scavenger-live-p-pr.md`](upstream-scavenger-live-p-pr.md).
- **`0012-mos-ldcimm-set-lowering.patch`** — surfaced once the scavenger no longer crashed (compilation
  reached MC lowering): `MOSMCInstLower` only lowered `LDCImm` for `0`/`-1`, but a *set* i1 carry can arrive
  as `1` (e.g. a 16-bit `SBC` carry-in) → `llvm_unreachable` on asserts (silent UB under NDEBUG). Fix: lower
  any nonzero i1 as `SEC`. Reproduces on a plain `+mos-a16` 16-bit subtract (not scavenger-specific). PR body:
  [`docs/upstream-ldcimm-set-lowering-pr.md`](upstream-ldcimm-set-lowering-pr.md).

Post (user-triggered) — mint branches off pristine `c798c31416f7`, then:

```
# scavenger fix
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-scavenger-live-p-save \
  --title "[MOS] Register scavenger: preserve a live processor-status register across an unbalanced stack range" \
  --body-file docs/upstream-scavenger-live-p-pr.md     # strip the status block first
# LDCImm lowering fix
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-ldcimm-set-lowering \
  --title "[MOS] Lower LDCImm set-carry from any nonzero i1, not only -1" \
  --body-file docs/upstream-ldcimm-set-lowering-pr.md  # strip the status block first
```

The original issue-only draft ([`docs/321-upstream-scavenger-nz-issue.md`](321-upstream-scavenger-nz-issue.md))
is retained for history with a SUPERSEDED banner. Full internal analysis + resolution:
[`docs/investigations/65816-a16-scavenger-nz-liveness.md`](investigations/65816-a16-scavenger-nz-liveness.md) ·
[plan](plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md).

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

### 8 — DP-arg calling-convention issue (an issue, **not** a PR)

Source-verified write-up of an **upstream** crash, surfaced as the "dp→near" residual of the #320
far-pointer-value work: passing an `addrspace(1)` (8-bit direct-page) pointer as a **function argument**
crashes the backend. Root cause is `MOSCallingConv.td:65` — `CCIfPtr<CCAssignToReg<[RS1..RS7]>>` assigns
*every* pointer arg to a 16-bit `RS` pair (`CCIfPtr` = `CCIf<"ArgFlags.isPointer()">`, address-space-blind),
so an 8-bit `addrspace(1)` pointer gets a 16-bit home → illegal `%vreg:(p1) = COPY $rsN` (`Def Size = 8,
Src Size = 16`). Three faces: `-verify-machineinstrs` rejects it; an asserts build aborts at
`MOSRegisterInfo.cpp:1059` (`copyCost`, during RA); a release build SIGSEGVs in `MOSLateOptimization`.
**No fork patch** (issue only — the fix is address-space-aware CC assignment, e.g. `CCIfPtrAddrSpace<1, …>`
to an 8-bit slot; maintainer territory). Reproduces on a **pristine** build at base `mos6502` (no
`+mos-a16`/`mosw65816`); our vendor pin `c798c31` == upstream `main`. 2-line repro included. File it:

```
gh issue create --repo llvm-mos/llvm-mos \
  --title "[MOS] Calling convention passes an addrspace(1) (8-bit direct-page) pointer argument in a 16-bit register — illegal size-mismatched COPY" \
  --body-file docs/320-upstream-dp-arg-cc-issue.md   # strip the status block first
```

Full internal record: [far-value residuals plan §Part A](plans/2026-06-22-320-far-value-residuals.md).

## Future / blocked (not yet postable — do **not** count these as pending)

- **#320 five-address-space model + PR.** The real far-pointer codegen PR (asiekierka's 32-bit-default /
  packed 24-bit / zero-bank / abs-16 layout). Blocked on maintainer **ABI blessing** — gated behind posting
  the #320 design note above. Not drafted as a PR yet. **The fork-side implementation body is now large and
  feature-complete (2026-06-21/22)** and would form the bulk of this PR once unblocked — now **landed on
  `main`** as `patches/llvm-mos/0001` (a16-free) + `0004` (far-ptr CC, Imag32 winner) + `0005` (the lone
  a16-context-entangled `MOSLegalizerInfo` PF-as-value hunk) + **`0006`** (AS3 packed-24: the 3-byte far-ptr
  storage form for tables, incl. the static-init relocation fix); round-trip-proven against
  `wt/320-far-followups` (also pushed `origin/wt/320-far-followups`). **All five of asiekierka's spaces are
  now measured** — AS0/1/2 ship, AS3 packed-24 built (measured win), and **AS4 zero-bank = CONFIRMED
  measured-null** (2026-06-22 de-lumped census `dev/measure-zerobank-census.sh`: bit-identical to a near
  pointer, 0 realistic bank-0-far sites; the five-space model is complete). The **packed-24 productionization
  thread is CLOSED** (2026-06-22, [close-out](plans/2026-06-22-320-packed24-residuals-close.md)): Task A
  measured + verified, Task C (`__far_packed` spelling) closed (no AS2 spelling to mirror), and Task B (byte-2
  absolute-long cost) is the near-abs bank-relaxation `0007` — its plan is literally "the realization of Task
  B". That separate optimization (`0007`, near globals → `abs` not `abs-long`, for ALL near pointers) is built
  on `wt/320-near-abs-bank-relax`, **now folded onto `main`'s patch stack** (`0001`–`0007`, 2026-06-22):
  - **far calls (b):** far→near mixed-banking via the bank-0 thunk `__call_near_from_far` (shipped to `main`).
  - **far function pointers (a):** the p2-value sub-project (Layers 1–3 + Gap A/B), the `jsl __call_indir_far`
    indirect-call mechanism, **and the clang front-end (F2):** a MOS **`far`/`long_call`** function/type
    attribute (`MOSFarCall`) — notably it reuses the MIPS `long_call`/`far` GNU spelling via a **shared
    `ParseKind="LongCall"`** (the same multi-target pattern `interrupt` uses), and a `CGExpr`/`CGExprScalar`
    rewrite to the `store @__mos_far_target` + `call @__call_indir_far` shape. Both a **direct** `far` call
    and a **stored** `far_fn_t fp = far_leaf; fp(x)` pointer work in single-file C (a `far` bit on
    `FunctionType::ExtInfo` → `ptr addrspace(2)`). **Completed in Phase B (2026-06-26, `ec4a80b`):** the
    runtime stub `__call_indir_far`/`__mos_far_target` (`platforms/snes/call-indir-far.s`) — authored on the
    retired follow-ups worktree but never landed — is now in the tracked SDK, so a far-indirect call **links +
    runs** (`far_fnptr.c`, `0xFF` both emulators; was `ld.lld: undefined symbol`). Also fixed a **pre-existing
    far-indirect-from-far-caller miscompile**: a far function calling `__call_indir_far` was mis-routed through
    `__call_near_from_far` (`IsFarNearThunk` captured the bank-0 thunk global) → stack corruption (the indir
    thunk `jml`s away, never returns to the near thunk's `pea` site); fix excludes `__call_indir_far` from
    `IsFarNearThunk` so it JSLs directly (`far_indir_tail.c`).
  - **far-pointer sizing:** `getPointerWidthV(AS2)`→32 + a `getTypeInfoImpl` arm so `sizeof(FAR*) ==
    sizeof(far_fn_t) == 4` (matches the `p2:32:8` IR width).
  - **a crash fix worth flagging upstream-adjacent:** `isFarSymbol` was treating any `.far*`-sectioned
    symbol as far (24-bit), crashing when a `.far_rodata` datum's address is taken as a *near* pointer;
    restricted to **functions** (`isa<Function>`). This is a fix to fork-only far machinery, so it rides the
    same #320 PR rather than standing alone.
  - **far tail calls — all three forms (2026-06-23..26, `0001`):** the post-RA tail-call peephole
    (`MOSLateOptimization::tailJMP`) keyed only on near `JSR`/`RTS`, so a far function's `JSL g; RTL` tail was
    never converted. Added a `TailJML` pseudo (→ `JMP_AbsoluteLong`/`$5C`, relocates `R_MOS_ADDR24`) + a far
    arm that now folds **three** provably-far callees, each matched precisely (conservative — a misclass only
    misses a win): (a) a **direct far global** (`isGlobal && .far_`, `4adda8b`); (b) the **far→near** thunk
    `__call_near_from_far` (an external symbol — matched by name, `ff3694c`); (c) the **far-indirect** thunk
    `__call_indir_far` (a bank-0 global — matched by name, Phase B `ec4a80b`). Each folds `JSL;RTL → TailJML`
    (−1 B, drops the redundant return push/pop); the `RTL` terminator proves the frame is far, so the
    dangerous near→far `JSL;RTS` shape can't match. a16-independent. Verified `dev/run.sh far_tail`/
    `far_near_call`/`far_indir_tail` (`0xCB`/`0xE0`/`0xFF`) MAME+bsnes-jg.
  - **far array-subscript miscompile fix (2026-06-25, `0001`):** clang's `EmitArraySubscriptExpr`/`EmitIdxAfterBase`
    (`CGExpr.cpp`) promoted the GEP index to the **default 16-bit `IntPtrTy`** for every address space, so a far
    (AS2, 32-bit) subscript `tbl[idx]` emitted `sext_i16(idx)*2` — truncating indices ≥ 32768 and corrupting the
    bank byte (silent miscompile; far indexed loads only worked within one 64 KiB bank). Fixed to promote to the
    **base pointer's per-AS index width** (`getIntPtrType(ctx, TargetAS)`) — generically correct (a no-op for
    single-pointer-width targets; only bites an AS *wider* than the default = far). **Now regression-guarded by a
    dedicated committed gate (2026-06-26):** `dev/run.sh farindex` — `examples/65816/farindex.c`, promoted from an
    open repro to a passing gate, reads a `const FAR uint16_t tbl[]` spanning banks $C1/$C2/$C3 at three runtime
    indices via `lda [dp]` and folds `corpus_result==0x0001D8A1`, host == +mos-a16 on MAME + bsnes-jg. Also
    exercised in production by the ~200 KiB sin-LUT-in-far-rodata work (`platforms/snes-hirom`, `dev/run.sh k_trig32lut`
    `0x87F0B404` MAME+bsnes-jg, corpus 7/7). Like the `isFarSymbol` fix, it touches fork-only far machinery (AS2 isn't
    upstream) so it rides the #320 PR — but the `CGExpr` change is itself generic. Drafted: [`docs/320-upstream-far-subscript-index-fix.md`](320-upstream-far-subscript-index-fix.md).
  Verified end-to-end on **MAME + bsnes-jg** (the whole far suite, 12 ROMs incl. `far_tail`) + corpus 7/7 + csmith 0-mismatch.
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
  **Stage-1 surface measured-complete (2026-06-22):** `dev/measure-native-s16-surface.sh` consolidates the
  per-op ALU/compare/shift/load-store + chains + cross-block M-flag + A16-threading surface — all at their
  measured optimum; the sustained-16-bit kernel class is **−22 % aggregate** vs the 8-bit build (corpus 7/7),
  while 8/16-interleave stress kernels are larger (opt-in/per-op-gated by design, lessons #1/#2) — with **one**
  shared deferred core (RA-level 16-bit residency under register pressure). The drafted upstream "stage-1
  native-s16 is measured-complete" paragraph is in the
  [surface consolidation plan](plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md) (posting
  rides this same ABI-gated native-16-bit contribution; user-triggered).
  **32-bit `long`/`int32_t` now value-verified (2026-06-23):** the `+mos-a16` s32 representation
  (2×s16 + 4×s8↔s32 (un)merge + `__mulsi3`/`__udivsi3`/`__umodsi3` libcalls) gained a dedicated `a16s32`
  4-way differential micro-test and a gated `--s32` track in the builtin fuzzer (lockstep C-emit/Python-oracle,
  deterministic) — strengthens the test story carried with this contribution. Test/tooling only, no codegen
  change. [plan](plans/2026-06-23-321-32bit-long-verification.md).

> *(The ROADMAP-step-6 DWARF **test + docs** item moved up to **Ready to post now #5** on 2026-06-19 —
> both halves are now drafted: the staged lit test + the `<output>.elf` doc note.)*

## Hygiene — leftover fork branch — RESOLVED (deleted 2026-06-23)

`wbniv/llvm-mos:revert-540-fix/soft-stack-spill-crash` (a leftover **revert** branch of **upstream PR #540**,
"fix(MOS): use reserved RS8 for soft stack spill scratch register", **MERGED upstream 2026-01-26**) was
**deleted by the user on 2026-06-23** (`gh api -X DELETE
repos/wbniv/llvm-mos/git/refs/heads/revert-540-fix/soft-stack-spill-crash`). It was the documented corner
case: a *revert* of an *already-merged* PR, so "retain until merged upstream" was already satisfied; no open
PR used it. No leftover fork branches remain.

**Standing policy (user, 2026-06-21) unchanged: keep fork branches around — do not auto-propose deleting
them.** This one was removed on the user's explicit request, which is the only condition under which a fork
branch is deleted.

## Verified state (GitHub, 2026-06-25)

Our first upstream contributions are now live: **2 PRs + 1 issue open** (was 0 through 2026-06-22).
**Re-verified 2026-06-25:** unchanged — #561/#562/#563 all still **OPEN** (none merged), the three fork
branches (`mos-dp-arg-cc`, `mos-late-opt-txy-dead-flag`, `mos-dwarf-65816-test-docs`) intact, all nine
drafted `*-upstream-*` artifact docs present.

```
$ gh pr list --repo llvm-mos/llvm-mos --author wbniv --state all
#563 [OPEN] [MOS] Pass addrspace(1) (8-bit direct-page) pointer arguments in an 8-bit register
#562 [OPEN] [MOS] mos-late-opt: clear dead/kill flags when rewriting LDImm to TYX/TXY

$ gh issue list --repo llvm-mos/llvm-mos --author wbniv --state all
#561 [OPEN] [MOS] Calling convention passes an addrspace(1) ... pointer argument in a 16-bit register
            (fixed by PR #563 — Fixes #561, auto-closes on merge)

$ gh api repos/wbniv/llvm-mos/branches --jq '.[].name' | grep -v '^main$'
mos-dp-arg-cc                              # PR #563 — DP-arg CC fix (pushed 2026-06-23)
mos-late-opt-txy-dead-flag                 # PR #562 — F4 dead-flag fix
mos-dwarf-65816-test-docs                  # DWARF step-6 PR — pushed, not yet opened (queue #5)
# (revert-540-fix/soft-stack-spill-crash deleted 2026-06-23 — stale revert of merged #540)

$ gh pr view 540 --repo llvm-mos/llvm-mos --json number,title,state,mergedAt
{"number":540,"title":"fix(MOS): use reserved RS8 for soft stack spill scratch register",
 "state":"MERGED","mergedAt":"2026-01-26T22:23:07Z"}
```

> **Note — two repos, don't conflate.** The PRs/issues/branches above target **`wbniv/llvm-mos`** (the LLVM
> compiler fork → upstream `llvm-mos/llvm-mos`). Separately, the **project** repo `wbniv/llvm-mos-65816`
> (this bench + the tracked `patches/`) had its `main` pushed to `e39d0ed` on 2026-06-23 (carrying fork
> patch `0008` + the #561/#563 artifacts); `main` has since advanced with later bench work. Either way
> that is *our* history, not an upstream contribution.

## Refresh this snapshot

```
gh pr list --repo llvm-mos/llvm-mos --author wbniv --state all      # what we've opened upstream
gh api repos/wbniv/llvm-mos/branches --jq '.[].name'               # pushed branches = candidate PRs
ls docs/32*upstream* docs/320-upstream*                            # drafted artifacts in the repo
```

Cross-check the drafted-artifacts list against the TODO **Upstream / Contribution** section; each `*upstream*`
doc here should map to a TODO item, and vice-versa.
