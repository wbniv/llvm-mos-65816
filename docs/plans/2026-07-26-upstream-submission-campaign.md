# Upstream submission campaign — turning the queue into merged PRs

**Status:** plan for user review (2026-07-26). **Nothing is posted, no branches pushed, no PRs opened
until the user reviews this doc and triggers each step** — posting is user-triggered per standing
policy; this plan only sequences the work and pre-verifies mechanics. Companion queue:
[`docs/upstream-contribution-status.md`](../upstream-contribution-status.md) (per-artifact rows +
drafted bodies + exact `gh` commands); companion presentation layer (built 2026-06-24,
[plan](2026-06-24-reviewer-patch-series-presentation.md)): review guide + LLVM primer +
`dev/upstream-status.sh`.

## Momentum

Our first two upstream contributions are **MERGED**: [PR #562](https://github.com/llvm-mos/llvm-mos/pull/562)
(F4 TYX/TXY dead-flag fix) and [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563) (DP-arg CC fix,
auto-closed issue #561). Both landed essentially as submitted. That's the proof the channel works —
small, self-contained, test-carrying fixes with honest write-ups get merged. This campaign applies the
same shape to the rest of the queue.

> **Update 2026-07-26 (later, campaign continuation):** upstream tip moved `8be054612` →
> **`8b616af94`** — exactly one new commit, `feat(lld/ELF): support garbage collection of
> .debug_frame sections (#567)`, touching only `lld/ELF/*` + two lld tests (no `llvm/` or MOS-backend
> files). Re-verified in a shared-object scratch clone at the new tip: **all five Wave-1/3 artifacts
> (`0010`/`0011`/`0012`/`0015`/`0016`) still `git apply --check` CLEAN**; the `0016` branch
> (`e54ef471d546`, MOSLegalizerInfo.cpp + new test only) has no file overlap with #567, so the PR
> merges clean as-is, and the RED-proof claim ("reproduced on `8be054612`") remains accurate — #567
> is lld-only, so `llc` behavior at the new tip is identical. #567 modifies
> `lld/ELF/Writer.cpp`, one of the two files on the DWARF branch (`0ae9415`) — **re-checked live:
> the cherry-pick auto-merges CLEAN onto `8b616af94`** (Wave 1 item 3 postable as-is). All five
> `0016` demo links re-verified HTTP 200. `gh` remains unauthenticated — Wave 1 item 1 is blocked
> on `gh auth login`.

## Verified state (2026-07-26, via `git ls-remote` — `gh` unauthenticated on this box)

| Fact | Value |
|---|---|
| `llvm-mos/main` tip | **`8be054612`** — *identical to our rebase base*, so everything below is verified against the **current** tip, not a stale one |
| `wbniv/llvm-mos` branches | `main` (stale at `c798c3141`) · `mos-dwarf-65816-test-docs` (`0ae9415`) — the two merged-PR branches are deleted (normal post-merge cleanup) |
| `llvm-mos-sdk/main` tip | `61e4e1ad` (the setjmp issue's target repo) |

**Per-artifact `git apply --check` against pristine `8be054612`** (run 2026-07-26 in a clean worktree):

| Artifact | Applies clean? | Note |
|---|---|---|
| `0010-coalesce-rotate-ac` | ✅ | |
| `0011-mos-scavenger-live-p-save` | ✅ | |
| `0012-mos-ldcimm-set-lowering` | ✅ | |
| `0015-321-coalesce-rc-undef` | ✅ | |
| `0016-mos-scmp-ucmp-legalize` | ✅ | |
| `0017-321-a16-s64-unmerge-anyext-legalize` | ❌ (irrelevant) | **Not a submission artifact at all** — it completes OUR OWN a16 legalizer glue, so it dissolves into the #321 series (already folded into `0002`); upstream only ever sees the finished feature. File kept as provenance. Same principle covers `0009`, `0014`, the zp-alloc Imag32 fix, and the xy16 REP/SEP fix (which always lived inside `0002`): **fixes to fork features fold into the feature patch — no introduce-then-fix sequences upstream.** |

## The waves, in posting order

Ordering principle: **standalone first** (reproduces on stock `llvm-mos`, no fork dependency —
zero-controversy merges that build reviewer trust), then issues, then judgment calls, then the design
notes that open the ABI conversation, then the big series that depends on it.

### Wave 1 — standalone bug-fix PRs (stock-llvm-mos reproducible)

1. **`0016` — `G_SCMP`/`G_UCMP` legalization** (issue + PR). *The best next post.* Any program that
   `qsort`s with the standard spaceship comparator `(a>b)-(a<b)` crashes the stock backend
   (`unable to legalize G_SCMP`) at every width, `-fno-lto` and LTO alike; the fix is **one line**
   (`.lower()` next to the analogous min/max rule) riding LLVM's own `lowerThreewayCompare`.
   **Prep needed: PR body + minimal-repro issue body not yet drafted as docs** (the status-doc row has
   the outline + suggested `gh` commands); needs a lit test extracted from the fork (the fix currently
   carries none upstream-shaped). Branch to mint: `wbniv:mos-scmp-ucmp-legalize`.
2. **`0010` — coalesce-rotate-`Ac` silent miscompile** (PR). Default-8-bit (no fork features): the
   register coalescer strands a loop-carried CRC byte; `shouldCoalesce` refusal + committed
   `-run-pass=register-coalescer` lit test. **Body drafted:**
   [`docs/upstream-coalesce-rotate-ac-pr.md`](../upstream-coalesce-rotate-ac-pr.md). Branch:
   `wbniv:mos-coalesce-rotate-ac`.
3. **DWARF step-6 lit test + `<output>.elf` doc note** (PR). Branch already pushed (`0ae9415`) but it
   was cut from `c798c3141` — **re-verify it still applies/passes on `8be054612` before posting**
   (docs+test only, so likely trivial). Body: [`docs/321-upstream-dwarf-output-elf-companion.md`](../321-upstream-dwarf-output-elf-companion.md).

### Wave 2 — issues (no code, low friction)

4. **`reentrant` can't force the soft stack** — independent of #321; issue body ready at
   [`docs/upstream-reentrant-soft-stack-issue.md`](../upstream-reentrant-soft-stack-issue.md).
5. **rc-undef-ra-pure-virtual verifier reject** (generic sub-register-undef liveness; deliberately an
   issue, not a blind patch) — [`docs/upstream-rc-undef-ra-pure-virtual-issue.md`](../upstream-rc-undef-ra-pure-virtual-issue.md).

   *(Superseded, do NOT post:* [`docs/321-upstream-scavenger-nz-issue.md`](../321-upstream-scavenger-nz-issue.md)
   *— the old issue-with-no-fix for the scavenger crash; `0011`'s fix PR replaces it. And*
   [`docs/321-upstream-lto-a16-bitmask-loop-early-exit-issue.md`](../321-upstream-lto-a16-bitmask-loop-early-exit-issue.md)
   *is the RETRACTED 2026-06-28 misdiagnosis — banner says do-not-post; it stays that way.)*
6. **llvm-mos-sdk: 6502-only `setjmp.S` breaks `longjmp` on 65816 native mode** — different repo
   (`llvm-mos/llvm-mos-sdk`); our `platforms/snes/setjmp.S` fix can be offered in-thread and later ride
   the SNES-platform contribution.

### Wave 3 — a16-reachable crash fixes (user judgment wanted)

`0011` (scavenger live-`$p`) and `0015` (coalesce-rc-undef guard) are latent stock bugs whose current
trigger paths go through the fork's `+mos-a16`/`+mos-xy16`. `0012` is instead a baseline MOS MC-lowering
contract, now covered directly by a `mos65c02` MIR test. All three are small, self-contained changes.
**Decision for the
user:** post them in this wave with that framing (recommended — they are maintainer-friendly and shrink
the eventual #321 series), or hold them to ride the #321 series itself.

### Wave 4 — design notes (open the ABI conversation)

7. **#320 five-address-space design note** → then the **far-CC measurement note** as its follow-up →
   then the **#321 CC frame-ABI note**. These unblock everything in Wave 5; they are posts to the
   #320 issue/Discord, not PRs. Bodies all drafted (status-doc rows #3, #7, #6).

### Wave 5 — the big series (blocked on Wave 4's ABI blessing)

The #320/#321 body: `0001` + `0002` (+ `0006` generic hook, `0014`, `0017`, and the new
**zp-alloc Imag32 CSR-rename fix** — fork-only registers, inseparable from #320). The presentation
layer for this wave is **already built** ([plan](2026-06-24-reviewer-patch-series-presentation.md)):
the [review guide](../65816-patch-series-review-guide.md) (reviewer's map, per-patch need/patch/proof,
Appendix D bug-fix slice), the [LLVM primer](../llvm-primer-for-65816-review.md) (for reviewers who
know compilers but not LLVM), and [`dev/upstream-status.sh`](../../dev/upstream-status.sh) (one-command
live refresh, needs `gh auth`). Not draftable as PRs until the AS2/ABI conversation lands.

## Mechanical protocol per submission (regen scripts are retired — this replaces them)

For each artifact, at posting time and **only after user go-ahead**:

1. **Fresh base**: worktree/clone of `llvm-mos/llvm-mos` at the then-current `main` tip.
2. **Apply the frozen artifact** (`git apply` — all Wave-1/3 artifacts verified clean against
   `8be054612` above; hand-rebase if the tip has moved and it conflicts).
3. **Build + test upstream-shaped**: the patch's lit test via the LLVM build
   (`ninja check-llvm-codegen-mos` or targeted `llvm-lit`), plus our fork-side differential gates stay
   green (the content is identical to what `0002` already carries — the fork build IS the ongoing
   soak test).
4. **Mint the branch** on `wbniv/llvm-mos` (named per the status-doc row), commit with a body derived
   from the drafted `docs/*-pr.md`, push the branch.
5. **Open the PR / issue** with the row's `gh` command (strip the doc's status preamble).
6. **Link the live SNES demos** (standing rule, user-directed 2026-07-26): every PR body links the
   playable biohack.net demo(s) that exercise the fix — the in-browser bsnes-jg pages whose
   "Verify fidelity" button re-runs the WRAM self-check live. It turns the "soak-tested" claim into
   something a maintainer can poke in 10 seconds. **Canonical URL form is
   `https://biohack.net/snes/<slug>/`** — the gallery evolves (it was being reorganized the day this
   was written), so **re-verify every link returns HTTP 200 (`curl -s -o /dev/null -w '%{http_code}'`)
   immediately before pasting into a PR body**; never post a cached link. The map (all 16 verified
   200 at the canonical form, 2026-07-26):

   | Artifact | Live proof demos |
   |---|---|
   | `0016` scmp/ucmp | [qsortviz](https://biohack.net/snes/qsortviz/) (finder) · [spaceship](https://biohack.net/snes/spaceship/) · [ucmprank](https://biohack.net/snes/ucmprank/) · [trimerge](https://biohack.net/snes/trimerge/) · [keycmp64](https://biohack.net/snes/keycmp64/) |
   | `0010` coalesce-rotate-Ac | [crcwall](https://biohack.net/snes/crcwall/) · [lfsr2](https://biohack.net/snes/lfsr2/) · [bitweave](https://biohack.net/snes/bitweave/) · [uarteye](https://biohack.net/snes/uarteye/) (Cluster D; default-8-bit leg load-bearing) |
   | `0011` scavenger live-`$p` | [pcooker](https://biohack.net/snes/pcooker/) (#109 re-stress) |
   | `0012` LDCImm set | baseline `mos65c02` `asm-printer.mir` regression; no ROM claimed |
   | `0015` coalesce-rc-undef | [newton](https://biohack.net/snes/newton/) (validated `0x4D8B`) |
   | `0017` s64 (un)merge | [dhmix](https://biohack.net/snes/dhmix/) (finder) · [mulov64](https://biohack.net/snes/mulov64/) · [oddmask](https://biohack.net/snes/oddmask/) · [modexp256](https://biohack.net/snes/modexp256/) |

7. **Same commit**: flip the status-doc row (drafted → posted, with PR number), mirror in TODO's
   *Upstream / Contribution* section.

Optional fork hygiene at the same time (user-triggered): fast-forward `wbniv/llvm-mos:main`
`c798c3141 → 8be054612` so PR diffs render against a fresh base.

## Hard guardrails

- **No PR, no issue, no branch push happens from this plan.** Every outward action is individually
  user-triggered after reviewing this doc and the per-item body.
- One artifact per PR; never bundle waves.
- Every posted PR body links repro + test; no claims beyond what the fork's gates actually verified.

## Immediate next actions — DONE 2026-07-26 (post-"ready")

- [x] `0016` issue + PR bodies drafted (`docs/upstream-scmp-ucmp-{issue,pr}.md`, live demo links in).
- [x] **Red/green proven on a pristine tip build** (`build/upstream-llc`, reusable for later waves):
      RED = `LLVM ERROR: unable to legalize instruction: %2:_(s8) = G_SCMP …` on unpatched
      `8be054612`; GREEN = official `llvm-lit` **`Passed: 1 (100.00%)`** with the fix + new
      `llvm/test/CodeGen/MOS/scmp-ucmp.ll` (folded into the `0016` artifact — now fix + test).
- [x] **Branch minted + pushed**: `wbniv:mos-scmp-ucmp-legalize` @ `e54ef471d546` (cut from tip).
- [x] DWARF branch (`0ae9415`) **cherry-picks clean onto `8be054612`** (`lld/ELF/Writer.cpp` +
      the test) — postable as-is; optionally rebase at posting time.
- [x] ~~**USER: post Wave 1 item 1** — open the issue, then the PR (commands atop each body doc),
      appending `Fixes #<issue>` to the PR body.~~ **DONE 2026-07-26** — user ran `gh auth login`
      (wbniv); posted as issue [#576](https://github.com/llvm-mos/llvm-mos/issues/576) + PR
      [#577](https://github.com/llvm-mos/llvm-mos/pull/577) (`Fixes #576` appended, demo links
      re-verified 200 same-day). Next: Wave 1 item 2 (`0010`, branch to mint) / item 3 (DWARF,
      postable as-is) — user-triggered.
- [x] **`0010` staged (2026-07-26, post-#577):** red/green proven on the same pristine build —
      RED = the new `coalesce-rotate-ac.mir` FAILS on unfixed `llc` (COPY coalesced away); GREEN =
      official `llvm-lit` **`Passed: 1 (100.00%)`** after applying `0010` + incremental `llc`
      rebuild. Branch **`mos-coalesce-rotate-ac` minted locally** in `vendor/llvm-mos` @
      `18244924b3d3` (cut from `8be054612`, the same base as `0016`; upstream-src worktree restored
      clean to `e54ef471`). The push was blocked by the permission layer — correctly, per the
      no-outward-actions guardrail — so it rides the user trigger. Demo links (crcwall/lfsr2/
      bitweave/uarteye) added to the PR body doc + verified 200. Post commands atop
      [`docs/upstream-coalesce-rotate-ac-pr.md`](../upstream-coalesce-rotate-ac-pr.md).
- [x] ~~**USER: post Wave 1 item 2** — push the minted branch, then `gh pr create` (commands atop the
      body doc).~~ **DONE 2026-07-26** (user: "finish wave 1; post items 2 and 3") — branch pushed,
      posted as [PR #578](https://github.com/llvm-mos/llvm-mos/pull/578).
- [x] ~~**USER: post Wave 1 item 3** — DWARF PR, postable as-is (command in status doc §5; cherry-pick
      re-verified clean onto `8b616af94`).~~ **DONE 2026-07-26** — posted as
      [PR #579](https://github.com/llvm-mos/llvm-mos/pull/579); body assembled from the drafted note
      (status block/metadata/Title/Posting sections stripped, test-half lead paragraph added).

**🏁 WAVE 1 COMPLETE (2026-07-26):** issue [#576](https://github.com/llvm-mos/llvm-mos/issues/576) +
PRs [#577](https://github.com/llvm-mos/llvm-mos/pull/577) /
[#578](https://github.com/llvm-mos/llvm-mos/pull/578) /
[#579](https://github.com/llvm-mos/llvm-mos/pull/579) all live upstream. Next: **Wave 2** (the three
issues — reentrant soft-stack, rc-undef-ra-pure-virtual, llvm-mos-sdk setjmp) — user-triggered.
