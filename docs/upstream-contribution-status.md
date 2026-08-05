# Upstream contribution status — what's drafted and pending to post

**Last updated:** 2026-08-04 (**BRK signature operand PR #586 and `llvm-mc` Motorola-default PR
#587 posted.** **#321 upstream disposition clarified: `0002` remains local.** There is no existing
#321 pull request; #321 is the upstream issue. The other open PRs (#577, #578, #579, #584, #586,
#587) are narrower independent changes and must not absorb the holistic native-width patch. A future
submission should describe the complete opt-in native-width implementation—not a "first stage"—and
rework `0002` into a reviewable commit series under one draft PR. Posting remains user-triggered;
wald3n.com remains pending until that PR has a real URL. **Implementation update:** the
#321 native-width series gained its asynchronous-boundary contract.
Round 7 #123 `nmitally` exposed that a 65816 C ISR inherited an unknown M/X state yet its prologue
assumed M8/X8. The fix is now folded into holistic patch `0002`: `MOSFrameLowering` saves full A/X/Y
under `rep #$30`, establishes M8/X8 for the generated body, restores under M16/X16, and lets `RTI`
restore stacked P. LLVM test + runtime host/default/a16/xy16 `0xDA3B` green; runnable explanation:
[https://biohack.net/snes/nmitally/](https://biohack.net/snes/nmitally/). This is **local #321-series content, not a standalone PR**; posting
notes: [PR blueprint](321-upstream-native-width-pr.md) ·
[interrupt addition](321-upstream-interrupt-width.md). Previously 2026-07-31
(**critique-improvements pass — the four then-open PRs improved and
updated in place** (plan:
[2026-07-31-upstream-pr-critique-improvements](plans/2026-07-31-upstream-pr-critique-improvements.md);
validation: a one-off MOS-only upstream build `~/llvm-mos/build-pr`, lit green per branch before
each push; none of the PRs had review activity, so 577/578 were amended in place).
[#577](https://github.com/llvm-mos/llvm-mos/pull/577) @ `67020e21c32c` — test strengthened
(per-function `CHECK-NOT: jsr` pins inline expansion at every width + new s32-result case).
[#578](https://github.com/llvm-mos/llvm-mos/pull/578) @ `edc9bbd23b71` — new
`coalesce-rotate-ac-no-pessimize.ll` (shift chains keep tight form, byte-identical to unguarded
output) + body v2 (scope/root-cause section: guard removes the *trigger*, downstream RA behavior
tracked separately; exact Csmith accounting incl. 142/160; drifted embedded patch dropped);
**companion RA issue DRAFTED, NOT posted** →
[upstream-coalesce-rotate-ac-ra-issue.md](upstream-coalesce-rotate-ac-ra-issue.md) (joins Wave 2).
[#584](https://github.com/llvm-mos/llvm-mos/pull/584) @ `3ce98fed82de` — **first record here:
POSTED 2026-07-31** (mos-late-opt non-GPR LDImm crash, from the 138 LZSS investigation) + new
commit hardening the sibling `TA` handler; body re-synced to the shipped defensive guard, mirror at
[upstream-late-opt-nongpr-ldimm-pr.md](upstream-late-opt-nongpr-ldimm-pr.md).
[#579](https://github.com/llvm-mos/llvm-mos/pull/579) @ `be45bd41c300` (branch had moved
`0ae9415`→`be45bd4` when the a16-dependent test was dropped; recorded now) — body-only edit:
confusing removed-test paragraph dropped, venue-flexibility line added.)
Previously 2026-07-26 #5 (**🏁 CAMPAIGN WAVE 1 COMPLETE — all three items posted.** Item 2:
`0010` coalesce-rotate-Ac = [PR #578](https://github.com/llvm-mos/llvm-mos/pull/578)
(`wbniv:mos-coalesce-rotate-ac` @ `18244924b3d3`, red/green-proven fix + `coalesce-rotate-ac.mir`,
four live-demo links). Item 3: DWARF step-6 = [PR #579](https://github.com/llvm-mos/llvm-mos/pull/579)
(`wbniv:mos-dwarf-65816-test-docs` @ `0ae9415`, lit test + `Writer.cpp` `<output>.elf` doc comment;
body assembled from the drafted note, test-half lead added). Upstream now shows **3 OPEN PRs
(#577/#578/#579) + 1 OPEN issue (#576)** from this campaign, all on 2026-07-26. Next: Wave 2 issues
(reentrant, rc-undef-ra, sdk setjmp) — user-triggered.) Previously 2026-07-26 #4 (**🚀 CAMPAIGN WAVE 1 ITEM 1 POSTED — `0016` G_SCMP/G_UCMP is live
upstream as issue [#576](https://github.com/llvm-mos/llvm-mos/issues/576) + PR
[#577](https://github.com/llvm-mos/llvm-mos/pull/577)** (head `wbniv:mos-scmp-ucmp-legalize` @
`e54ef471d546`, fix + `scmp-ucmp.ll` lit test, body carries `Fixes #576` + the five live-demo links).
Posted 2026-07-26 after the user ran `gh auth login` (account `wbniv`, keyring) — the auth blocker is
gone for the rest of the campaign. Next up: Wave 1 item 2 (`0010` coalesce-rotate-Ac, branch to mint)
and item 3 (DWARF, postable as-is) — both user-triggered.) Previously 2026-07-26 #3 (**tip moved `8be054612` → `8b616af94` (one commit: lld/ELF
`.debug_frame` GC, PR #567 — no MOS-backend files); all five Wave-1/3 patch artifacts
(`0010`/`0011`/`0012`/`0015`/`0016`) re-verified `git apply --check` CLEAN against the new tip in a
shared-object scratch clone. The new commit touches `lld/ELF/Writer.cpp`, one of the two files on the
DWARF branch (`0ae9415`) — re-checked live: **the cherry-pick auto-merges CLEAN onto `8b616af94`**
(no conflict; DWARF PR postable as-is). All five
`0016` demo links re-verified HTTP 200. `gh` still unauthenticated on this box — posting Wave 1 item 1
is blocked on `gh auth login` only.**) Previously 2026-07-26 #2 (**SUBMISSION CAMPAIGN PLANNED — see
[`docs/plans/2026-07-26-upstream-submission-campaign.md`](plans/2026-07-26-upstream-submission-campaign.md)**,
the wave-ordered posting sequence with per-item mechanics; posting stays user-triggered and NOTHING is
posted yet. Live state re-verified via `git ls-remote` (gh unauthenticated): `llvm-mos/main` tip is
**still `8be054612`** — identical to our rebase base, so the whole stack is verified against the
*current* tip; the two merged-PR fork branches (`mos-late-opt-txy-dead-flag`, `mos-dp-arg-cc`) are
deleted post-merge (normal cleanup — the retain-until-merged condition was satisfied), leaving `main`
(stale `c798c3141`) + `mos-dwarf-65816-test-docs` (`0ae9415`). **Per-artifact `git apply --check`
against pristine `8be054612`:** `0010`/`0011`/`0012`/`0015`/`0016` ALL apply clean — the stale-base
concern from earlier today is moot for every Wave-1/Wave-3 artifact; only `0017` needs the fork's
`0002` context (rides with #321, as recorded).) Previously 2026-07-26
(**standalone patch files `0004`–`0017` are now FROZEN posting artifacts.**
The `dev/regen-patch.sh` run for the zp-alloc Imag32 fix folded the MOS-dir-only `0016`/`0017` into the
comprehensive `0002` (build stack now `0001 → 0002 → 0006`-generic-hunks; see the
[rebase plan §Update 2026-07-26](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md)). The
standalone files still on disk — `0004`–`0007`, `0009`–`0017` — are the individually-reviewable
upstream-PR artifacts referenced by the rows below, but they are no longer regenerable from the live
tree: the 10 per-patch `dev/regen-patch-000N.sh` scripts are **retired** (loud `exit 2` + explanatory
header) because their additive baselines no longer exist. To refresh an artifact at posting time,
rebase the patch file itself against the then-current upstream base by hand. Note their recorded
"applies cleanly against pristine `c798c3141`" claims are stale — the base has moved past `8be054612`.)
Previously 2026-07-25 (**PR #562 and PR #563 both MERGED upstream** — discovered while doing a
from-scratch `dev/run.sh toolchain` build (publishing SNES demo `#102 cpu6502`), which surfaced that
`0003-late-opt-txy-dead-flag.patch` and `0008-mos-dp-arg-cc.patch` no longer `git apply` because their
fixes are already present in `llvm-mos/main`: **PR #562** ("F4" TYX/TXY dead-flag fix) merged as commit
`9142aebae`; **PR #563** (DP-arg CC fix, `Fixes #561`) merged as commit `8be054612` (which also
auto-closed **issue #561**). Both patches **retired** from `patches/llvm-mos/` (deleted) per the
"drop once merged + the vendor pin bumps" plan noted below. Fork branches `mos-late-opt-txy-dead-flag`
and `mos-dp-arg-cc` can be deleted now they're merged (standing policy: only on explicit user request —
not done here). See [rebase plan](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md).)
Previously 2026-07-01 (**`+mos-a16`/`+mos-xy16` s64↔s16 (un)merge + odd-width `G_ANYEXT`
legalization fix — READY-TO-POST, `#321`-scoped**. SNES demo #61 (Diffie-Hellman 64-bit modular
exponentiation) caught a backend crash: 64-bit arithmetic under `+mos-a16`/`+mos-xy16` emits
`G_UNMERGE_VALUES` splitting an `s64` into 16-bit lanes (`{S16,S64}`) and, for a mask-narrowed value, a
`G_ANYEXT` from an odd `s24` — neither had a legalizer rule, so the backend aborted with `unable to
legalize instruction: … = G_UNMERGE_VALUES %N:_(s64)` / `… = G_ANYEXT %N:_(s24)`. **Default 8-bit
compiles fine — the gap is only in the 16-bit-register modes** (the #321 fork's own s16-lane legalization,
which had s32↔s16/s8 glue but not the s64↔s16 level). Fix (all `hasAccum16()`-gated) = add the s64↔s16
(un)merge glue mirroring the existing s32 handlers (`legalizeMergeS64FromWords` /
`legalizeUnmergeS64ToWords`, the 2-level `s64 ↔ 2×s32 ↔ 4×s16` rewrite) + route odd-width `G_ANYEXT`
sources through `G_ZEXT` (high bits are don't-care). Carried as fork patch
**`0017-321-a16-s64-unmerge-anyext-legalize`** (round-trip-verified against pristine `c798c3141`);
regression-gated by `dev/run.sh dhmix` (`0x69AA`, 5-way + `-verify`), the minimal repro
[`docs/investigations/repro/a16-s64-unmerge.c`](investigations/repro/a16-s64-unmerge.c), and the full
corpus (62 slices, 0 regressions). Full write-up:
[`docs/investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md`](investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md).
**Posting is user-triggered** (this one is `#321`-scoped, not standalone like `0016` — it only reproduces
under `+mos-a16`/`+mos-xy16`, so it rides with the #321 upstreaming). No GitHub state change yet.)
Previously 2026-06-30 (**`G_SCMP`/`G_UCMP` legalization fix — READY-TO-POST, upstream-standalone**.
SNES demo #46 (`qsortviz`, a libc-`qsort` sort visualizer) caught a general backend crash: the standard C
three-way-compare comparator idiom `return (x>y)-(x<y);` is canonicalized by clang to the generic opcode
`G_SCMP`, and `MOSLegalizerInfo` had **no rule** for `G_SCMP`/`G_UCMP`, so the backend aborted with
`unable to legalize instruction: %N:_(s16) = G_SCMP`. Fires in **default 8-bit, +mos-a16, and +mos-xy16
alike**, at **every** integer width, in **both** `-fno-lto` and the LTO-link path — i.e. any program that
`qsort`s with a spaceship comparator fails to build. **Unlike the #320/#321 far-pointer fixes below, this
is NOT gated behind AS2/accum16 — it reproduces on plain vanilla `-mcpu=mosw65816` C, so it is directly
upstream-standalone-testable** and belongs as its own ready-to-post issue+PR against `llvm-mos/llvm-mos`.
Fix = one line in `llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` next to the analogous min/max lowering:
`getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();` — routing to LLVM's existing
`LegalizerHelper::lowerThreewayCompare` (icmp+select expansion the backend already legalizes). No
generic-LLVM change. Carried as fork patch **`0016-mos-scmp-ucmp-legalize`**; regression-gated by
`dev/run.sh qsortviz` (`corpus_result==0x8EA5`, 5-way differential + `-verify`) and the minimal repro in
[`docs/plans/2026-06-30-46-snes-qsortviz.md`](plans/2026-06-30-46-snes-qsortviz.md). **Posting is
user-triggered.** Suggested: an issue with the minimal repro + a PR with the one-line fix. `gh` commands to
draft when posting:
`gh issue create -R llvm-mos/llvm-mos -t "Backend abort: unable to legalize G_SCMP/G_UCMP (three-way compare) on MOS" -b "<minimal repro + backtrace>"`
then a PR from a fork branch with the `0016` hunk. No GitHub state change yet — nothing posted.)
Previously 2026-06-26 (**far-pointer-PHI legalization fix** — a far (addrspace 2) pointer used as a loop
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

- **✅ POSTED (campaign Wave 1, item 1, 2026-07-26):** `0016` G_SCMP/G_UCMP — issue
  [**#576**](https://github.com/llvm-mos/llvm-mos/issues/576) + PR
  [**#577**](https://github.com/llvm-mos/llvm-mos/pull/577) (`wbniv:mos-scmp-ucmp-legalize` @
  `67020e21c32c` — amended 2026-07-31, critique pass: `CHECK-NOT: jsr` + s32-result case; fix +
  `scmp-ucmp.ll`, `Fixes #576`, live-demo links in body).
- **✅ POSTED (campaign Wave 1, items 2+3, 2026-07-26): Wave 1 COMPLETE** —
  `0010` coalesce-rotate-Ac = [**PR #578**](https://github.com/llvm-mos/llvm-mos/pull/578)
  (`wbniv:mos-coalesce-rotate-ac`), DWARF step-6 =
  [**PR #579**](https://github.com/llvm-mos/llvm-mos/pull/579)
  (`wbniv:mos-dwarf-65816-test-docs`). **Wave 2 is next: 3 issues** (+ the llvm-mos-sdk
  `setjmp.S` bug, a different repo — plus, added 2026-07-31, the **rotate-ac RA companion** issue,
  row 16, gated on a maintainer response to #578). **Wave 3 (user judgment): 3 more PRs** — `0011`/`0012`/`0015`,
  latent stock bugs currently reachable only via the fork's a16/xy16; all apply clean to tip.
  **Wave 4: 3 design notes** → unblock the Wave-5 #320/#321 series. Full sequencing + per-item
  mechanics: [campaign plan](plans/2026-07-26-upstream-submission-campaign.md).
- **Open on GitHub right now: 0** — **all three of our first contributions merged/closed**:
  [PR #562](https://github.com/llvm-mos/llvm-mos/pull/562) (F4 — TYX/TXY dead-flag fix) merged as commit
  `9142aebae`; [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563) (the fix for #561) merged as
  commit `8be054612`, which auto-closed [issue #561](https://github.com/llvm-mos/llvm-mos/issues/561)
  (`Fixes #561`). Discovered 2026-07-25 (see *Last updated* above) — not re-checked live via `gh`, but
  both merge commits are directly visible in a fresh `llvm-mos/main` clone. #561+#562 opened 2026-06-22;
  #563 opened 2026-06-23.
- **Future / blocked (not yet draftable): 2** — the #320 five-address-space PR (ABI-blessing-gated) and the
  llvm-mos-sdk#415 engagement (someone else's existing PR).
- **Hygiene (re-verified 2026-07-26 via `ls-remote`):** the two merged-PR branches (`mos-dp-arg-cc`,
  `mos-late-opt-txy-dead-flag`) are **deleted** post-merge — the retain-until-merged condition was
  satisfied, so this is normal cleanup, not drift. Remaining: `main` (stale at `c798c3141`; optionally
  fast-forward to `8be054612` at posting time so PR diffs render fresh — user-triggered) and the active
  queue branch `mos-dwarf-65816-test-docs` (`0ae9415`). Standing policy unchanged: keep fork branches
  until merged upstream; **do not auto-propose deletion**.

## Ready to post now

| # | Item | Type | What it does | Drafted at | Branch |
|---|------|------|--------------|-----------|--------|
| 1 | ✅ **MERGED 2026-07-25 (discovered)** — **F4** — `mos-late-opt` TYX/TXY dead-flag fix | **PR** | Clears dead/kill flags when rewriting `LDImm`→TYX/TXY (verifier reject on reentrant `+mos-a16`). Merged upstream as commit `9142aebae`; fork patch `0003-late-opt-txy-dead-flag.patch` **retired** (deleted) — see [rebase plan](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md). | [`docs/321-upstream-late-opt-txy-pr.md`](321-upstream-late-opt-txy-pr.md) | [**PR #562**](https://github.com/llvm-mos/llvm-mos/pull/562) (opened 2026-06-22, **merged**) |
| 2 | **`reentrant` can't force the soft stack** | **issue** | Independent latent footgun: `__attribute__((reentrant))` is a no-op for non-recursive functions (`MOSNonReentrant` re-stamps `nonreentrant`). Discovered during native-width soft-stack test work, but not part of issue #321. | [`docs/upstream-reentrant-soft-stack-issue.md`](upstream-reentrant-soft-stack-issue.md) | n/a (issue; ready to file) |
| 3 | **#320** — far-pointer design note | **note** | Opens the five-address-space ABI-blessing discussion (a Discord/#320 post, not a code change). **Updated 2026-06-21** with the Phase 0/3 corrections: retracts the pow2-pointer-size premise (real reason = MVT has no i24), the C1 single-datalayout finding (`0=far-default` foreclosed → a clang flag), and the packed-24 representable-but-deferred position. Posting-ready (user-triggered). | [`docs/320-upstream-far-pointer-note.md`](320-upstream-far-pointer-note.md) | n/a (note) |
| 4 | ✅ **FIXED** — **scavenger live-`$p`** — `saveScavengerRegister` can't preserve a live `$p` across an unbalanced stack range | **fix PR** | Upstream crash (was an issue-with-no-fix): a `+mos-a16`/`+mos-xy16` compare keeps N/Z live across a frame-carry spill, forcing the whole `$p` preserved across an *unbalanced* range, but `$p` has no GPR home → illegal `STImag8 $p` + undefined-`$p` `PH $p`. **Fix** = route `$p` hard-stack-neutrally through a dead index reg into `RC17` + drop the stale `assertNZDeadAt`; carried as fork patch `0011` (`a16scavnz.c` now a `0x22A6` positive gate, both emulators, asserts-clean). | [PR body](upstream-scavenger-live-p-pr.md) · patch `patches/llvm-mos/0011-mos-scavenger-live-p-save.patch` | not yet pushed (`wbniv:mos-scavenger-live-p-save` to mint) |
| 5 | ✅ **POSTED 2026-07-26** — **DWARF step 6** — 65816 DWARF lit test + `<output>.elf` doc note | **PR** | ROADMAP step 6: pins verified DWARF shapes + documents the undocumented debug-companion `.elf` | [lit](../dev/lit/DebugInfo/MOS/dwarf-65816.ll) · [note](321-upstream-dwarf-output-elf-companion.md) | [**PR #579**](https://github.com/llvm-mos/llvm-mos/pull/579) (`wbniv:mos-dwarf-65816-test-docs` @ `be45bd41c300` — a16-dependent test dropped in review prep; body cleaned 2026-07-31, venue-flex line added) |
| 6 | **#321 CC frame-ABI** — measured frame-model evaluation | **note** | Implementation-backed CC evidence: DP-window/stack-relative are feasible but NULL on real code (locals are `__rc`-resident → frames ≈unused); keep the soft static stack, by measurement | [`docs/321-upstream-cc-frame-abi-note.md`](321-upstream-cc-frame-abi-note.md) | n/a (note) |
| 7 | **#320 far-CC** — measured ABI evaluation (far ptr across a call) | **note** | Implementation-backed CC evidence: all 4 ABIs built behind `+mos-farcc-*` + measured (bytes + round-trips/frame) on MAME+bsnes-jg → **Imag32 wins decisively** (70 B/50441; smallest *and* fastest). Far ptr should pass/return whole in one 4-byte imaginary-register unit, by measurement. **Follow-up to #3** — post after the design note opens the conversation. Shipped as `0004` in-fork. | [`docs/320-upstream-far-cc-measurement-note.md`](320-upstream-far-cc-measurement-note.md) | n/a (note) |
| 8 | ✅ **MERGED 2026-07-25 (discovered)** — **DP-arg CC** — `addrspace(1)` 8-bit pointer argument in a 16-bit register | **issue + fix PR** | Upstream crash: `CCIfPtr` (MOSCallingConv.td:65) assigns *every* pointer arg to a 16-bit `RS` pair, so an 8-bit `addrspace(1)` (direct-page) pointer arg → illegal `(p1)=COPY $rs`. **Fix** = a `CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2..RC15]>>` rule (8-bit slot) + a `-verify` CodeGen test; spike-validated (5 shapes, corpus 7/7). Merged upstream as commit `8be054612` (auto-closed #561); fork patch `0008-mos-dp-arg-cc.patch` **retired** (deleted) — its content also lived duplicated inside `0002`, which needs the same hunk hand-resolved — see [rebase plan](plans/2026-07-25-llvm-mos-fork-patch-stack-upstream-rebase.md). | [issue body](320-upstream-dp-arg-cc-issue.md) · [PR body](320-upstream-dp-arg-cc-pr.md) | [**#561**](https://github.com/llvm-mos/llvm-mos/issues/561) (2026-06-22, **closed**) → fixed by [**PR #563**](https://github.com/llvm-mos/llvm-mos/pull/563) (`wbniv:mos-dp-arg-cc`, 2026-06-23, **merged**) |
| 9 | **coalesce-rotate-Ac** — silent miscompile: rotate value coalesced into A-only `Ac` | **issue + fix PR** | Default-8bit miscompile (no `+mos-a16`): the register coalescer merges two shift/rotate-referenced values into the A-only `Ac` class, stranding a loop-carried CRC byte in `Y` while the back-edge `ROL` reads a stale `A` (inlined CRC16 bit loop under pressure). Both `-verify-machineinstrs`/`-verify-coalescing` clean. **Fix** = `MOSRegisterInfo::shouldCoalesce` refuses the join (`NewRC==Ac` ∧ both operands rotate-referenced) + a `-run-pass=register-coalescer` lit test; carried as fork patch `0010`, validated (repro `0xE60E`→`0xF56C`, corpus 7/7, torture 30/30, csmith 54/60 0-mismatch). ✅ **POSTED 2026-07-26** (PR only — the miscompile narrative lives in the PR body); **v2 2026-07-31** (critique pass): + `coalesce-rotate-ac-no-pessimize.ll`, body scope/root-cause section, companion RA issue drafted (row 16). | [PR body](upstream-coalesce-rotate-ac-pr.md) · patch `patches/llvm-mos/0010-coalesce-rotate-ac.patch` | [**PR #578**](https://github.com/llvm-mos/llvm-mos/pull/578) (`wbniv:mos-coalesce-rotate-ac` @ `edc9bbd23b71`) |
| 10 | ⏸ **ON HOLD (user decision 2026-08-04; body READY)** — **`LDCImm` set lowering** — `MOSMCInstLower` asserts a single carry-set encoding | **fix PR** | Baseline MOS `llvm_unreachable("Unexpected LDCImm immediate")` (asserts) / NDEBUG UB: `LDCImm` lowered only `0`/`-1`, but a set i1 can arrive as plain `1`. **Fix** = lower any nonzero i1 as `SEC`. The regression is now an ordinary `mos65c02` MIR asm-printer case beside the existing `0`/`-1` cases; it has no 65816 or native-width dependency. Surfaced during `0011` work, but technically independent; carried as fork patch `0012`. **Body revised 2026-08-04 (review pass):** now leads with the in-tree `!!Val`-vs-`-1` normalization inconsistency (`expandLDImm1` GPR path vs carry path), restores an honest Origin section (downstream a16 16-bit-SBC carry-in `1`; no in-tree producer identified — framed as hardening), and defends any-nonzero over an assert. **HOLD rationale (2026-08-04, user decision):** standalone it is declinable ("the unreachable encodes an invariant; fix your producer"); paired with `0011` it is self-evident. Post as a **pair with `0011`** (Wave 3) once the open queue shows maintainer engagement — six PRs (#577/#578/#579/#584/#586/#587) currently sit with zero maintainer comments/reviews. **Decoupling DONE 2026-08-04** (`357fe37`, standalone patch `0027-321-a16-sbc-carry-in-normalize.patch`): the fork's a16 `G_SUB` carry-in is now the sign-extended `-1` (proof: post-RA MIR shows `LDCImm -1`; `IsArith` decoupled from the sign so G_SUB keeps its carry-in; borrowlad `0x1BE3` + corpus-a16 59/62 green) — `0012` is now optional pure hardening on the fork's side. | [PR body](upstream-ldcimm-set-lowering-pr.md) · patch `patches/llvm-mos/0012-mos-ldcimm-set-lowering.patch` | local `mos-ldcimm-set-lowering` @ `60d9d7d25262`; **not pushed or posted** |
| 11 | ⛔ **RETRACTED — MISDIAGNOSIS (do NOT post)** — "LTO + `+mos-a16` bitmask-loop early exit" | ~~issue~~ | **Disproven 2026-06-28** by a controlled rebuild experiment ([plan](plans/2026-06-28-321-verify-lto-a16-bitmask-early-exit-diagnosis.md)). The `cmp #$10` is the loop's `q->n < UPQ_MAX_JOBS` guard (`UPQ_MAX_JOBS=16=0x10`), **not** the shift counter `r`: overriding `-DUPQ_MAX_JOBS=20` moves the constant to `cmp #$14` (tracks the macro). The `jmp rts` is the correct per-vblank DMA-budget exit (≤16 jobs/frame; 28 rows over 2 frames); the real `r<28` bound `cpy #$1c` is present. No row-skip miscompile exists. The original demo stall is a *separate, unverified* question (possible 32-bit `==0` LTO miscompile or frame ordering) → would need a **fresh, correctly-characterized** issue, not this one. | [issue body (banner-retracted)](321-upstream-lto-a16-bitmask-loop-early-exit-issue.md) | n/a — not to be posted |
| 12 | **coalesce-rc-undef** — verifier reject: call-clobbered `$rcN` value coalesced into a pair across the clobber | **fix PR** | `+mos-a16`/`+mos-xy16` under pressure: the register coalescer folds a value read straight out of a call-clobbered imaginary register (`vreg = COPY $rcN`) into an `Imag16` pair (sub-register copy) that outlives the clobbering call → the allocator re-binds the pair to `$rcN` across the clobber → disconnected `$x = COPY $rcN` def→use (`-verify-machineinstrs`: "Using an undefined physical register"; runs correctly, latent hazard). **Fix** = `MOSRegisterInfo::shouldCoalesce` refuses the join (`NewRC==Imag16` ∧ sub-register ∧ an operand's unique def is `COPY $rcN` live across a call clobbering `$rcN` via `checkRegMaskInterference`) + a `-run-pass=register-coalescer` lit test. Correctness-safe by construction; 4/34 corpus programs change (all `-verify` clean + differential green), 30 byte-identical. Validated: newton `0x4D8B` unchanged (MAME+bsnes-jg), `rcundef.c`+`newton_step` verify clean `-O0/-O1/-Os` a16+xy16. **Mint-ready:** the self-contained change (cpp + lit test) is `patches/llvm-mos/0015-321-coalesce-rc-undef.patch`, **verified `git apply --check` clean against pristine `c798c3141`** (the `0010` model); it also lands in the comprehensive fork patch `0002` for the live build. **Scope:** a second, distinct cause (RA binding a *pure-virtual* value to a clobbered `$rc` pair — lsystem/newton-`-O1`, item 13) is NOT fixed by this guard. | [PR body + mint cmd](upstream-coalesce-rc-undef-pr.md) · patch `patches/llvm-mos/0015-321-coalesce-rc-undef.patch` (clean vs pristine) | not yet pushed (`wbniv:mos-coalesce-rc-undef` to mint) |
| 14 | ⚠️ **RECLASSIFIED 2026-07-26 — NOT a postable artifact; dissolves into the #321 series** — a16 s64↔s16 (un)merge + odd-width `G_ANYEXT` | ~~fix PR~~ **series content** | `+mos-a16`/`+mos-xy16` abort (default 8-bit OK): 64-bit arithmetic emits `G_UNMERGE_VALUES {S16,S64}` (split s64 into 16-bit lanes) and, for a mask-narrowed value, `G_ANYEXT {S32,S24}` — neither had a legalizer rule (the #321 fork added s32↔s16/s8 glue but not the s64 level). **Fix** = add the s64↔s16 (un)merge glue mirroring the s32 handlers (`legalizeMergeS64FromWords`/`legalizeUnmergeS64ToWords`, 2-level `s64↔2×s32↔4×s16`) + route odd-width `G_ANYEXT` through `G_ZEXT` (don't-care high bits); all `hasAccum16()`-gated. Found by SNES demo #61 (DH 64-bit modexp). Validated: repro + demo compile, **62 corpus slices 0 regressions**, 64-bit demos differential-green, `-verify` clean. Carried as fork patch `0017` (round-trip vs pristine `c798c3141`). | [investigation + repro](investigations/2026-06-30-a16-s64-unmerge-anyext-legalize-crash.md) · patch file kept as **provenance only** (content folded into `0002` 2026-07-26) | n/a — completes OUR OWN a16 legalizer glue ("the #321 fork added s32↔s16/s8 glue but not the s64 level"), so upstream must only ever see the finished feature; same class as `0009`/`0014`/the zp-alloc Imag32 fix |
| 13 | **rc-undef-ra-pure-virtual** — verifier reject: dead read of an `undef` `Imag16` sub-lane after RA (cause #2) | **issue** | The *second* distinct cause of the same "Using an undefined physical register" message — **not** a coalescer issue. A 16-bit `__mulsi3` argument built with the `undef %N.sublo:imag16 = COPY …` idiom (high lane undef) is RA-assigned a `$rc` pair; the undef high lane is tracked live to a **dead** full-pair read (`$x = COPY $rcN`, `$x` immediately overwritten) but no instruction materializes it. Lowering the virtual sub-register read to the physical `$rcN` **loses the `undef` flag**, so the dead read trips the verifier. Code-correct (lsystem `0x79C3`, newton `0x4D8B`). Generic-RA / sub-register-undef-liveness; candidate fixes (propagate `undef` onto the physreg read, or DCE the dead extract) are toolchain-wide and need a full regression sweep — **filed as an issue**, not patched blindly. Repro: `lsystem_sim.c` `main`, `newton_sim.c` `newton_gate_crc` `-O1`. Tracked downstream as `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]` (lsystem XFAIL). **Second manifestation folded in 2026-08-04:** `seqvm.c` `draw_frame` hits the same cause but the surviving read **feeds a store** (`STAbs %378, %stack.2+1`) rather than being dead — still code-correct (`dev/run.sh seqvm` → `0xE8C5`), so the verifier-only framing holds, but "the copy is dead" is not the safety invariant. Issue body now carries the vreg chain (480B→712B→716B→736B), the withdrawn "premature kill flag / miscompile potential" misdiagnosis, the ruled-out `-enable-subreg-liveness`, and the re-verified repro (2 errors `$rc3` bb.2 / `$rc5` bb.5 at `-Os`, clean `-O0`/`-Oz`). **Residual:** decide whether to attempt the toolchain-wide fix. | [issue body](upstream-rc-undef-ra-pure-virtual-issue.md) | **NOT POSTED** — n/a (issue); filing is user-triggered |
| 15 | ✅ **POSTED 2026-07-31** — **late-opt non-GPR LDImm** — `mos-late-opt` null-pointer crash on an SPC700 `LDImm` to an imaginary register | **fix PR** | Upstream hard crash from 7 lines of plain C at `-O1`+: `combineLdImm` switches its `ImmLoad*` over `{A,X,Y}` then stores through it unconditionally, but on SPC700 `MOSInstrInfo::getRegClass` widens `LDImm`'s destination to `Anyi8`, so `$rcN = LDImm imm` is legal, verifier-clean MIR → null store. **Fix** = GPR-class guard + defensive invalidation of any modified tracked GPR (`7eedb14`), + sibling `TA`-handler hardening from the 2026-07-31 critique pass (`3ce98fe`); `late-opt-spc700.mir` red/green (SIGSEGV before, lit green after). Found via the 138 LZSS-gallery far-decode investigation (32-bit imaginary register hit the same store). | [PR body mirror](upstream-late-opt-nongpr-ldimm-pr.md) · provenance: [138 plan](plans/2026-07-27-138-lzss-far-decode-mos-late-optimization-crash.md) | [**PR #584**](https://github.com/llvm-mos/llvm-mos/pull/584) (`wbniv:mos-late-opt-nongpr-ldimm` @ `3ce98fed82de`); PR body's live-byte claim corrected to the measured matrix (3 live bytes crash at O1+, 2 at `-Oz`); fork carry `patches/llvm-mos/0003-late-opt-nongpr-ldimm-dest.patch` (`0999cfa`, merged to main 2026-08-01) |
| 17 | ✅ **READY TO POST (verified 2026-07-31)** — **zp-alloc determinism** — `MOSZeroPageAlloc` picks zero-page winners in heap-address order | **fix PR** | Upstream **reproducible-build** defect (any target using `-mlto-zp`; no `+mos-a16` needed): `collectCandidates` accumulates benefits in a `DenseMap<GlobalVariable *, float>` and iterates it to build the candidate list, so candidates arrive in pointer-hash (heap-address) order; the later `stable_sort` on benefit leaves ties in exactly that order, and whichever tied global is visited first takes the last free zero-page byte. **Fix** = three order-preserving container swaps, no heuristic change: `GlobalBenefit` and `CalleeFreqs` `DenseMap`→`MapVector` (the latter also fixes non-associative `float +=` accumulation into `EntryFreqs`, which perturbs *near*-ties), `SCCCallees` `SmallSet`→`SmallSetVector` (`SmallSet` degrades to pointer-ordered `std::set` past its inline capacity, and `SCC::Callees` seeds the round-robin `EntryGraph` list). Repro: 8 tied 1-byte globals + `-zp-avail=4` → **6 distinct winner sets in 20 single-threaded `llc` runs**; the gallery ROM gave **2 distinct 1 MiB images in 30 links** from byte-identical LTO IR (1476/2291 symbols shifted +2 B). **VERIFIED on a rebuilt toolchain 2026-07-31:** minimal case 6 distinct winner sets → **1** (`g0 g1 g2 g3`, 20/20 — the declaration order `MapVector` predicts); gallery ROM 2 images → **1** (`a4e00f3b…`, 20/20); lit test `zp-alloc-deterministic.ll` **0 pass/20 fail → PASS**; `llvm/test/CodeGen/MOS/` 81 tests / 7 failures = exactly the pre-existing fork-divergence set, **no new failures**. ⚠️ **Rebuild gotcha:** `dev/run.sh toolchain` does **not** rebuild `build/llvm-mos/bin/llc` (not in the distribution component list) — a stale `llc` reproduced the old 6-way split and failed the new lit test after a green build; rebuild it explicitly (`cmake --build /work/build/llvm-mos --target llc`). | [PR body](upstream-zp-alloc-deterministic-pr.md) · patch `patches/llvm-mos/0021-mos-zp-alloc-deterministic.patch` (`git apply --check` clean vs pristine `8be0546128a5`, reverse-clean vs live vendor) · provenance: the discarded throwaway `gallery-repro-bisect` worktree; durable record = the [PR body](upstream-zp-alloc-deterministic-pr.md) Reproduction/Verification | **MINTED 2026-08-04, ready to post** — `mos-zp-alloc-deterministic` @ `1c3deb021a53` local in `~/llvm-mos` (cut from tip `1f334fef`, parent verified; red/green re-proven there, determinism test stable 5/5, suite fully green: CodeGen 79 pass/0 fail + upstream-disabled getchar-regression, MC 39/39 [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.]). Exact push+post commands in the [PR body banner](upstream-zp-alloc-deterministic-pr.md). NOT pushed/posted (user-triggered). |
| 18 | ✅ **READY TO POST (2026-08-02)** — **late-opt `CmpZero` lowering skipped after the first fold** | **fix PR** | `MOSLateOptimization::lowerCmpZeros` used the function's loop-carried `Changed` accumulator as its per-instruction "did this fold?" flag, so after the first fold in a block every later-processed `CmpZero` took the early `continue` and was never lowered. Nothing downstream lowers the pseudo: it is legal MIR (so `-verify-machineinstrs` is silent) and the asm printer emits **nothing** for it — the promised flag test vanishes with no diagnostic. **Reproduces on pristine upstream** (`build/upstream-llc`, 4-line MIR, no fork feature). **Fix** = per-`CmpZero` `Folded` flag; also set `Changed` on the `allDefsAreDead()` erase path (it mutated while reporting no change). Regression `late-opt-cmpzero-after-fold.mir` (survivor before / lowered after + `CHECK-NOT: CmpZero`). Suite: 83 tests, exactly the 7 pre-existing fork-divergence failures. **Measured incidence in-tree: ZERO** — 140 files × 4 configs, 17,403 blocks, max 1 `CmpZero` per block — so the fix is inert here and the finding is a latent-hazard fix for upstream, stated as such in the PR body. | [PR body](upstream-late-opt-cmpzero-lowering-pr.md) · patch `patches/llvm-mos/0022-mos-late-opt-cmpzero-lowering.patch` (applies clean on pristine `8be0546128a5` AND tip `1f334fef`, reverse-clean vs live vendor) · provenance: [plan](plans/2026-08-02-lowercmpzeros-sticky-changed.md) | ✅ **POSTED 2026-08-04** as [**PR #589**](https://github.com/llvm-mos/llvm-mos/pull/589) (`wbniv:mos-late-opt-cmpzero-lowering` @ `8c8d28b0c35a`, cut from tip `1f334fef`). Publish note: the originally-minted commit (`f8cfe68b`) had landed on the cop branch after a concurrent branch switch in the shared clone — repaired by cherry-pick onto bare tip + cop-branch reset to `3ac1097` (PR #588 unaffected); red/green + late-opt suite re-proven on the repaired branch before the push. Body cites #584 + the public incidence-scan write-up. |
| 16 | **coalesce-rotate-Ac RA companion** — greedy RA mishandles an `Ac`-pinned loop-carried live range (the *underlying* defect behind #578) | **issue** | #578's guard removes the *trigger* (the join that pins the range); the downstream behavior — RA parks the value in `Y` on the skip path and never restores `A` before the back-edge `ROL`, from verifier-clean MIR — is unfixed and in principle reachable by a shape whose two rotate uses arrive at RA already on one vreg (no COPY to keep). No standalone repro extractable (four-way pressure simultaneity, see the reduction); filed as latent-hazard documentation with analysis + candidate directions (restore-before-use contract, forbid `Ac` for loop-carried ranges, post-RA single-reg-class verifier). Referenced from #578's body ("happy to file a companion issue"). **Post after (or with) a maintainer response on #578.** | [issue body](upstream-coalesce-rotate-ac-ra-issue.md) | not posted (Wave 2; drafted 2026-07-31) |
| 20 | **branch-range diagnostics (`0019`)** — out-of-range `PCRel8`/`PCRel16` branch fixups assemble silently, offset truncated | **fix PR** | `MOSAsmBackend::applyFixup` applies the PC-relative correction and writes the value without a range check — an out-of-range branch silently lands elsewhere. **Fix** = post-correction range check + source-located `... branch target out of range` errors, with `branch-range-errors.s` pinning both messages. Carried as `patches/llvm-mos/0019-mos-branch-range-diagnostic.patch` (tracked standalone stack, `e8ccda8`). ⚠ **Coordination: touches the SAME hunk as open [PR #549](https://github.com/llvm-mos/llvm-mos/pull/549)** (mlund's 65CE02 PC-correction fix, still **OPEN** as of 2026-08-04) — complementary changes; post WITH or AFTER #549, rebasing over it if it lands first. **Minted + verified 2026-08-04:** `0019` applied cleanly to tip `1f334fef02b5` (no hand-resolution); red/green proven by `git stash` + tool-complete rebuild (llvm-mc, llc, opt, llvm-readelf, llvm-objdump all rebuilt and confirmed newer than the changed source); `llvm/test/MC/MOS/` 40/40, `llvm/test/CodeGen/MOS/` 78/79 + 1 UNSUPPORTED (`getchar-regression.ll`, pre-existing), both 0 failed / exit 0. | [PR body draft](upstream-branch-range-diagnostic-pr.md) · patch `patches/llvm-mos/0019-mos-branch-range-diagnostic.patch` | local `mos-branch-range-diagnostic` @ `4195df6e3b56`; **not pushed or posted** (gate: #549 timing) |
| 21 | **65816 `BRL` branch relaxation** — extend [PR #550](https://github.com/llvm-mos/llvm-mos/pull/550)'s 16-bit relaxation gate to `HasW65816` | **fix PR (future)** | mlund's #550 widens `isBranchOffsetInRange` on 65CE02+ so MC relaxation promotes 8→16-bit branches instead of BranchRelaxation inserting `JMP` trampolines (their measurement: 19→0 trampolines, 3 B/1+ cyc each). The 65816 has `BRL` upstream and the identical opportunity — every SNES ROM we build would shrink. **Blocked on #549+#550 landing** (both open; #550 depends on #549). Nothing in the fork does this today (we only reorder the relaxation pass for REP/SEP sizing). Option meanwhile: a supportive comment on #550 offering the `HasW65816` leg. | analysis in-session 2026-08-04 (no draft yet) | not started (gated on #549/#550) |
| 18a | ✅ **POSTED 2026-08-04** — **optional BRK signature operand** | **fix PR — fast track** | Baseline MOS accepts only bare `brk`. Standalone additive fix keeps `BRK_Implied` unchanged and adds assembler-only `BRK_Immediate`; bare `brk` remains `[00]`, while decimal `brk #66` becomes `[00 42]` under bare `llvm-mc`. The regression deliberately avoids `$` syntax so this PR is independent of item 19. COP is explicitly excluded. | [BRK-only PR body](upstream-brk-signature-operand-pr.md) · patch `patches/llvm-mos/0024-mos-brk-signature-operand.patch` · [split plan](plans/2026-08-04-split-brk-cop-patch-ownership.md) | [**PR #586**](https://github.com/llvm-mos/llvm-mos/pull/586) (`wbniv:mos-brk-signature-operand` @ `064d33fc43ca`) |
| 18b | ✅ **POSTED 2026-08-04** — **COP mnemonic + signature operand** — 65816 opcode `$02` was absent | **fix PR** | W65816-only assembler support remains separate from baseline BRK ownership. The fork carries `COP_Immediate` in the a16 patch and the natural-mnemonic ROM gate passes. **Design DECIDED 2026-08-04: MANDATORY operand (the fork's `0002` shape — decoder-visible 2-byte decode, bare `cop` rejected); the combined draft's optional design is retired. Reduction spec + rationale in the draft's banner. **Reduction DONE 2026-08-04:** branch `wbniv:mos-65816-cop-mnemonic` @ `3ac109760642` (cut from upstream main, independent of #586, not pushed), COP-only body rewritten (`44d0274`, self-stripping post commands in its banner); red/green per test, MC suite 39/40 (`addr-asciz.s` pre-existing), new `cop-signature.s` carries the load-bearing `mos65el02` predicate guard + positive 2-byte disasm round-trip.** | [as-posted body](upstream-cop-brk-signature-pr.md) · [split plan](plans/2026-08-04-split-brk-cop-patch-ownership.md) | [**PR #588**](https://github.com/llvm-mos/llvm-mos/pull/588) (`wbniv:mos-65816-cop-mnemonic` @ `3ac109760642`, 2026-08-04, **open**) |
| 19 | ✅ **POSTED 2026-08-04** — **`llvm-mc` clobbers the target's Motorola-integer default** | **fix PR (tiny)** | `AsmLexer` initializes from `MCAsmInfo::shouldUseMotorolaIntegers()`, but `llvm-mc` unconditionally overwrites it from a default-false option. Fix: call `setLexMotorolaIntegers` only when the option occurred. Focused regression proves bare MOS `$ea` encodes as `0xea` while explicit false still yields the symbolic fixup. Kept independent of BRK PR #586, whose test uses decimal `#66`. Regression dates to llvm-mos PR #352 (2023-09-21), exposing an override introduced by LLVM commit `4db18d62afa8` (2021-01-26). | [PR body](upstream-llvm-mc-motorola-default-pr.md) · [plan](plans/2026-08-04-llvm-mc-motorola-default.md) · patch `patches/llvm-mos/0025-llvm-mc-preserve-motorola-default.patch` | [**PR #587**](https://github.com/llvm-mos/llvm-mos/pull/587) (`wbniv:llvm-mc-preserve-motorola-default` @ `579bc0f087c1`) |
| 17 | **MVN/MVP block-move bank-order** — llvm-mos 65816 `MVN`/`MVP` MC operand-encoding defect (bank order) | **fix PR** | Found by the svx2 animated-video work (2026-07-31): the MC instruction format encodes the `MVN`/`MVP` bank operands in the wrong order, producing a wrong-bank block move from correct assembly. Fixed in the fork (TableGen format fix + opcode regression) as patch `0020-mos-65816-block-move-bank-order.patch` (commit `d71d298`). **To do before posting** (curated as a `[T2]` TODO bullet, 2026-08-03): reduce to the MC opcode test, confirm syntax + byte order vs WDC docs and llvm-mos asm conventions, run the focused MC test + suite, mint a minimal branch (`wbniv:mos-65816-mvn-bank-order` to mint), frame the animated ROM as reproducer without asset coupling. | patch `patches/llvm-mos/0020-mos-65816-block-move-bank-order.patch` · [svx2 plan §Upstream compiler follow-up](plans/2026-07-31-svx2-animated-video-cartridge.md) | not yet minted/posted |

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
  --body-file docs/upstream-reentrant-soft-stack-issue.md
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
  case, flag the wholly-undefined `PHP` `undef`, drop the stale `assertNZDeadAt`, widen
  `canSaveScavengerRegister(P)`. PR body: [`docs/upstream-scavenger-live-p-pr.md`](upstream-scavenger-live-p-pr.md).
  **Revised 2026-08-01 (still unposted, so the revision lands in the same patch):** the `undef`
  predicate was a *reaching-definition* scan (`hasNoReachingDef`) and therefore under-fired — the
  machine verifier tracks **forward availability** and accepts the composite use when *any*
  sub-register is available, so a `$c` that is defined above and then killed/dead-flagged leaves
  `$p` wholly undefined at the `PHP` while a reaching-def scan still sees a modifier and declines
  to flag it. `-verify-machineinstrs` tripped on exactly that shape in `examples/snes/seamdemo.c`
  (`seamvm_step`), where an a16 ADC chain defines `$c` repeatedly and dead-flags the last one. The
  predicate is now `hasNoAvailableValue`, built on `LivePhysRegs::addLiveIns` + `stepForward` +
  `available()` — the verifier's own set. `0011` now also carries the regression test
  `llvm/test/CodeGen/MOS/scavenger-p-undef.mir`, which pins **both** directions in one function
  (`PH undef $p` where nothing is available; plain `PH $p` where `$c` is), so an over-eager `undef`
  — the only direction that could miscompile — fails the test too.
- **`0012-mos-ldcimm-set-lowering.patch`** — surfaced once the scavenger no longer crashed (compilation
  reached MC lowering): `MOSMCInstLower` only lowered `LDCImm` for `0`/`-1`, but a set i1 can arrive as
  plain `1` → `llvm_unreachable` on asserts (UB under NDEBUG). Fix: lower any nonzero i1 as `SEC`.
  Regression: baseline `mos65c02` MIR in `asm-printer.mir`; no 65816 feature or ROM required. PR body:
  [`docs/upstream-ldcimm-set-lowering-pr.md`](upstream-ldcimm-set-lowering-pr.md).

Post (user-triggered) — mint branches off pristine `c798c31416f7`, then:

```
# scavenger fix
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-scavenger-live-p-save \
  --title "[MOS] Register scavenger: preserve a live processor-status register across an unbalanced stack range" \
  --body-file <(sed '0,/-->/d; /^# \[MOS\]/d' docs/upstream-scavenger-live-p-pr.md)
# LDCImm lowering fix
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-ldcimm-set-lowering \
  --title "[MOS] Lower LDCImm set-carry from any nonzero i1, not only -1" \
  --body-file <(sed '0,/-->/d; /^# \[MOS\]/d' docs/upstream-ldcimm-set-lowering-pr.md)
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

### 9 — `longjmp` broken on the 65816 — `setjmp.S` is 6502-only (an **llvm-mos-sdk** issue, not a PR)

Surfaced scoping demo #35 (the `setjmp`/`longjmp` battery member). The SDK's common
`mos-platform/common/c/setjmp.S` is a **6502** implementation: `setjmp` reads the return address from a
**hardcoded page `$0100`** (`tsx`; `lda $101,x`/`$102,x`) and saves only the **8-bit** hard stack pointer
(`txa`); `longjmp` restores it with `tax; txs`. On the **65816 in native mode** (which the SNES crt0 enters
via `XCE`) the stack pointer **S is 16-bit and not page-1-bound**, so `longjmp` restores a corrupted S and
`rts`-es to a garbage address — **`longjmp` never returns**. `setjmp` + normal return works; only the
`longjmp` restore is broken. Reproduces in **default-8-bit AND `+mos-a16`** → pre-existing upstream, **not**
the #321 fork.

**FIXED in the fork 2026-07-02** — the fix rides with our **SNES platform** (the natural upstream home, since
`common/c/setjmp.S` is compiled once as 6502 and merged into every `libc.a`, so an `#ifdef` there would never
fire for the SNES). New **`platforms/snes/setjmp.S`** (built `-mcpu=mosw65816`, added to `snes-c` ahead of the
`common-c` merge so it shadows common's 6502 `setjmp.S.obj` by archive order) reconstructs the page-1 16-bit
`S = $01xx` (`ora #$0100; tcs`) instead of the broken `txs`, and reads/writes the return address
stack-relative — **no `jmp_buf` ABI change** (the SNES stack is page-1 by crt0 contract). Verified through the
full differential: **host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg**, all
`corpus_result = 0x2007` (regression guard `corpus/setjmp_sim.c`). Plan:
[35-setjmp-longjmp-65816-fix](plans/2026-07-02-35-setjmp-longjmp-65816-fix.md).

**Upstream posture:** this belongs in llvm-mos-sdk's SNES platform. It should land **as part of the SNES
platform PR** (llvm-mos-sdk#415 reconciliation — see *Future / blocked*), since upstream has no SNES platform
target yet to compile a 65816 `setjmp.S`. Standalone, still file the bug so it's tracked:

```
gh issue create --repo llvm-mos/llvm-mos-sdk \
  --title "[65816] longjmp corrupts the stack pointer in native mode — common setjmp.S is 6502-only (8-bit page-\$0100 stack)" \
  --body-file docs/investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md   # trim to the repro + root cause + our fix
```

Full internal record: [setjmp/longjmp 65816 investigation](investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md)
(root cause) + [fix analysis report](investigations/2026-07-02-setjmp-longjmp-65816-fix-analysis.md) (design
rationale + verification, for the PR narrative).

## Future / blocked (not yet postable — do **not** count these as pending)

- ~~**MC-layer `cop` mnemonic (assembler gap, found by demo #140, 2026-08-04).**~~ ✅ **POSTED
  2026-08-04** as [**PR #588**](https://github.com/llvm-mos/llvm-mos/pull/588)
  (`wbniv:mos-65816-cop-mnemonic` @ `3ac10976`, cut from `1f334fef`): `cop` with a **mandatory**
  signature operand (WDC's own asymmetry vs #586's optional BRK; decoder-visible 2-byte decode —
  `$02 5a` now disassembles as `cop #$5a`, was `<unknown>` + bogus byte), `FeatureW65816`-gated
  (`$02` is `NXT` on the 65EL02, pinned by a negative RUN line). MC suite fully green — 40/40 on the PR branch. [CORRECTED 2026-08-04: the earlier '5 pre-existing failures on pristine tip' / '39/40 lone failure' claims were exit-127 tool-missing artifacts of the minimal build-pr tool set (opt, llvm-readelf absent); with the tools built the suites are fully green — CodeGen 79 pass + getchar-regression.ll upstream-disabled (UNSUPPORTED: target), 0 failures; MC 39/39 (+ the branch's own new tests). Rule: build the tools the suite RUNs before quoting numbers; exit-127 in a lit log is an environment defect.] Body pre-flighted: source link verified 200 post-push; a16/xy16 wording de-forked
  (`cb87da8`). [As-posted body](upstream-cop-brk-signature-pr.md) ·
  [#140 plan](plans/2026-08-04-140-snes-brkcop.md).
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

**Update 2026-07-25 (discovered, not re-verified live via `gh`):** #562 and #563 are merged — found by
inspecting a fresh `llvm-mos/main` clone (commits `9142aebae` and `8be054612`), not by re-running the
`gh` commands above. `dev/upstream-status.sh` should be re-run to get a live-verified snapshot and
replace this note with a proper `gh`-sourced one.

**Update 2026-07-26 (`git ls-remote` — real remote state, no auth needed; `gh` still unauthenticated
here so PR/issue metadata is still not live-queried):**

```
$ git ls-remote https://github.com/llvm-mos/llvm-mos.git refs/heads/main
8be0546128a5...  refs/heads/main          # == our rebase base; tip has NOT moved
$ git ls-remote https://github.com/wbniv/llvm-mos.git   # branches only
c798c3141...  main                        # stale; FF to 8be054612 at posting time (user-triggered)
0ae94157b...  mos-dwarf-65816-test-docs   # active queue branch (campaign Wave 1, item 3)
# mos-dp-arg-cc + mos-late-opt-txy-dead-flag: DELETED post-merge (normal cleanup)
$ git ls-remote https://github.com/llvm-mos/llvm-mos-sdk.git refs/heads/main
61e4e1ad5e85...  refs/heads/main          # setjmp-issue target repo
```

Plus per-artifact `git apply --check` vs pristine `8be054612` (clean worktree):
`0010` ✅ · `0011` ✅ · `0012` ✅ · `0015` ✅ · `0016` ✅ · `0017` ❌ (needs `0002` context; rides #321).
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
